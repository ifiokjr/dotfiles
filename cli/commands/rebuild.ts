/**
 * `dotfiles rebuild` — Rebuild Nix configuration and redeploy groups
 *
 * Native TypeScript orchestration for the legacy rebuild flow. This command
 * still invokes system tools (`git`, `nix`, `nh`, `brew`) because those are the
 * actual rebuild backends, but it no longer shells out to the legacy `rebuild`
 * script.
 */

import { Command } from "@cliffy/command";
import { exists } from "@std/fs";
import {
	formatCommand,
	machineConfigPath,
	printError,
	printHeader,
	printInfo,
	printSuccess,
	printWarning,
	resolveDotfilesDir,
	resolveNixConfigDir,
	runCommand,
} from "../lib/config.ts";
import { installDotfilesCli } from "./self.ts";

interface RebuildOptions {
	addPreset?: string;
	alwaysOn?: boolean;
	brew?: boolean;
	desktop?: boolean;
	dryRun?: boolean;
	force?: boolean;
	groups?: string;
	latest?: boolean;
	lite?: boolean;
	noAlwaysOn?: boolean;
	noDesktop?: boolean;
	noLite?: boolean;
	rebuildOs?: boolean;
	removePreset?: string;
	skipCheck?: boolean;
	update?: boolean;
}

interface MachineConfig {
	alwaysOn: boolean;
	isDesktop: boolean;
	lite: boolean;
	presets: string[];
	system: string;
	username: string;
}

interface RebuildContext {
	dotfilesDir: string;
	flakeDir: string;
	nixConfigDir: string;
	rootOnlyNix: boolean;
}

interface CommandSpec {
	args: string[];
	cwd?: string;
	env?: Record<string, string>;
}

export const rebuildCommand = new Command()
	.description(
		"Rebuild system configuration (nix-darwin switch or home-manager switch)",
	)
	.option(
		"--groups <groups:string>",
		"Only deploy specific groups after rebuilding (reserved; not yet implemented natively)",
	)
	.option("--skip-check", "Skip flake check before rebuilding")
	.option("--update", "Update flake inputs before rebuilding")
	.option("--brew", "With --update on macOS, run brew upgrade --cask --greedy")
	.option("--lite", "Set machine.nix lite = true before rebuilding")
	.option("--no-lite", "Set machine.nix lite = false before rebuilding")
	.option("--desktop", "Set machine.nix isDesktop = true before rebuilding")
	.option("--no-desktop", "Set machine.nix isDesktop = false before rebuilding")
	.option(
		"--latest",
		"Update dotfiles repo to the latest version before rebuilding",
	)
	.option("--force", "With --latest, hard-reset to origin/main")
	.option("--rebuild-os", "Install macOS software updates before rebuilding")
	.option("--always-on", "Set machine.nix alwaysOn = true before rebuilding")
	.option(
		"--no-always-on",
		"Set machine.nix alwaysOn = false before rebuilding",
	)
	.option(
		"--add-preset <preset:string>",
		"Add a machine preset before rebuilding",
	)
	.option(
		"--remove-preset <preset:string>",
		"Remove a machine preset before rebuilding",
	)
	.option("--dry-run", "Show the rebuild plan without executing")
	.action(async (opts: RebuildOptions) => {
		validateOptions(opts);

		const dotfilesDir = await resolveDotfilesDir();
		const nixConfigDir = await resolveNixConfigDir(dotfilesDir);
		const flakeDir = await Deno.realPath(nixConfigDir);
		const machinePath = machineConfigPath(nixConfigDir);

		prependBootstrapPath();
		const rootOnlyNix = await isRootOnlyNix();
		const context: RebuildContext = {
			dotfilesDir,
			flakeDir,
			nixConfigDir,
			rootOnlyNix,
		};

		printHeader("Rebuilding system configuration");

		if (opts.latest) {
			await updateDotfilesRepo(context, opts);
		}

		await updateMachineConfig(machinePath, opts);
		const config = await readMachineConfig(machinePath);
		printMachineConfig(config, machinePath);

		if (opts.dryRun) {
			printPlan(context, config, opts);
			return;
		}

		await ensureNixAvailable();
		await maybeInstallOsUpdates(opts);
		await maybeUpdateFlake(context, opts);
		await maybeCheckFlake(context, opts);
		await runRebuild(context, config);
		await installDotfilesCli({ dotfilesDir: context.dotfilesDir });

		if (opts.groups) {
			printWarning(
				"Native --groups deployment is not implemented yet; rebuild completed without group redeploy filtering.",
			);
		}
	});

function validateOptions(opts: RebuildOptions) {
	if (opts.force && !opts.latest) {
		printError("--force requires --latest");
		Deno.exit(1);
	}

	if (opts.brew && !opts.update) {
		printError("--brew requires --update");
		Deno.exit(1);
	}

	if (opts.lite && opts.noLite) {
		printError("Cannot use both --lite and --no-lite");
		Deno.exit(1);
	}

	if (opts.desktop && opts.noDesktop) {
		printError("Cannot use both --desktop and --no-desktop");
		Deno.exit(1);
	}

	if (opts.alwaysOn && opts.noAlwaysOn) {
		printError("Cannot use both --always-on and --no-always-on");
		Deno.exit(1);
	}
}

async function updateDotfilesRepo(
	context: RebuildContext,
	opts: RebuildOptions,
) {
	if (opts.force) {
		printInfo("Hard-resetting dotfiles to origin/main (--force)");
		await runRequired({
			args: ["git", "fetch", "origin"],
			cwd: context.dotfilesDir,
		});
		await runRequired({
			args: ["git", "checkout", "main"],
			cwd: context.dotfilesDir,
		});
		await runRequired({
			args: ["git", "reset", "--hard", "origin/main"],
			cwd: context.dotfilesDir,
		});
		await runRequired({
			args: ["git", "clean", "-fd"],
			cwd: context.dotfilesDir,
		});
		return;
	}

	const originalBranch = await captureCommand([
		"git",
		"branch",
		"--show-current",
	], context.dotfilesDir);
	const hasChanges = (await captureCommand(
		["git", "status", "--porcelain"],
		context.dotfilesDir,
	)).trim() !== "";
	let stashed = false;

	try {
		if (hasChanges) {
			printInfo("Stashing local changes in dotfiles repo");
			await runRequired({
				args: ["git", "stash", "push", "-m", "dot rebuild --latest auto-stash"],
				cwd: context.dotfilesDir,
			});
			stashed = true;
		}

		printInfo("Resetting dotfiles to latest from origin/main");
		await runRequired({
			args: ["git", "fetch", "origin"],
			cwd: context.dotfilesDir,
		});
		await runRequired({
			args: ["git", "checkout", "main"],
			cwd: context.dotfilesDir,
		});
		await runRequired({
			args: ["git", "reset", "--hard", "origin/main"],
			cwd: context.dotfilesDir,
		});
	} finally {
		if (stashed) {
			printInfo("Restoring stashed changes");
			await runCommand(["git", "stash", "pop"], { cwd: context.dotfilesDir });
		}

		if (originalBranch && originalBranch !== "main") {
			printInfo(`Switching back to branch ${originalBranch}`);
			await runCommand(["git", "checkout", originalBranch], {
				cwd: context.dotfilesDir,
			});
		}
	}
}

async function updateMachineConfig(machinePath: string, opts: RebuildOptions) {
	const updates: Array<[string, boolean]> = [];
	if (opts.lite) updates.push(["lite", true]);
	if (opts.noLite) updates.push(["lite", false]);
	if (opts.desktop) updates.push(["isDesktop", true]);
	if (opts.noDesktop) updates.push(["isDesktop", false]);
	if (opts.alwaysOn) updates.push(["alwaysOn", true]);
	if (opts.noAlwaysOn) updates.push(["alwaysOn", false]);

	let content = await Deno.readTextFile(machinePath);

	for (const [field, value] of updates) {
		content = setBooleanField(content, field, value);
		printSuccess(`Updated machine.nix default: ${field} = ${value}`);
	}

	if (opts.addPreset) {
		content = setPreset(content, opts.addPreset, true);
		printSuccess(`Added machine preset: ${opts.addPreset}`);
	}

	if (opts.removePreset) {
		content = setPreset(content, opts.removePreset, false);
		printSuccess(`Removed machine preset: ${opts.removePreset}`);
	}

	if (updates.length > 0 || opts.addPreset || opts.removePreset) {
		await Deno.writeTextFile(machinePath, content);
	}
}

function setBooleanField(
	content: string,
	field: string,
	value: boolean,
): string {
	const line = `  ${field} = ${value ? "true" : "false"};`;
	const pattern = new RegExp(`^\\s*${field}\\s*=\\s*(true|false);\\s*$`, "m");

	if (pattern.test(content)) {
		return content.replace(pattern, line);
	}

	return content.replace(/\n}\s*$/, `\n${line}\n}`);
}

function setPreset(content: string, preset: string, enabled: boolean): string {
	const presets = parsePresets(content);
	const next = enabled
		? Array.from(new Set([...presets, preset]))
		: presets.filter((entry) => entry !== preset);
	const line = `  presets = [${next.map((entry) => `"${entry}"`).join(" ")}];`;

	if (/^\s*presets\s*=\s*\[.*\];\s*$/m.test(content)) {
		return content.replace(/^\s*presets\s*=\s*\[.*\];\s*$/m, line);
	}

	return content.replace(/\n}\s*$/, `\n${line}\n}`);
}

async function readMachineConfig(machinePath: string): Promise<MachineConfig> {
	const content = await Deno.readTextFile(machinePath);
	const username = readStringField(content, "username");
	const system = readStringField(content, "system");

	if (!username || !system) {
		printError("Failed to read username or system from machine.nix");
		printWarning("Please check that machine.nix is properly formatted");
		Deno.exit(1);
	}

	return {
		alwaysOn: readBooleanField(content, "alwaysOn"),
		isDesktop: readBooleanField(content, "isDesktop"),
		lite: readBooleanField(content, "lite"),
		presets: parsePresets(content),
		system,
		username,
	};
}

function readStringField(content: string, field: string): string {
	return content.match(new RegExp(`${field}\\s*=\\s*"([^"]+)"`))?.[1] ?? "";
}

function readBooleanField(content: string, field: string): boolean {
	return content.match(new RegExp(`${field}\\s*=\\s*(true|false)`))?.[1] ===
		"true";
}

function parsePresets(content: string): string[] {
	const body = content.match(/presets\s*=\s*\[([^\]]*)\]/s)?.[1] ?? "";
	return Array.from(body.matchAll(/"([^"]+)"/g), (match) => match[1]);
}

function printMachineConfig(config: MachineConfig, machinePath: string) {
	printInfo(`Reading machine configuration from: ${machinePath}`);
	printInfo("Configuration:");
	console.log(`  Username: ${config.username}`);
	console.log(`  System: ${config.system}`);
	console.log(`  Lite: ${config.lite}`);
	console.log(`  Desktop: ${config.isDesktop}`);
	console.log(`  Always On: ${config.alwaysOn}`);
	if (config.presets.length > 0) {
		console.log(`  Presets: ${config.presets.join(", ")}`);
	}
	console.log("");
}

function prependBootstrapPath() {
	const home = Deno.env.get("HOME") ?? "";
	const currentPath = Deno.env.get("PATH") ?? "";
	const paths = [
		"/nix/var/nix/profiles/default/bin",
		"/run/current-system/sw/bin",
		`${home}/.nix-profile/bin`,
		`${home}/.local/state/nix/profiles/home-manager/home-path/bin`,
		`${home}/.local/bin`,
		"/usr/local/bin",
		"/usr/bin",
		"/bin",
		"/usr/sbin",
		"/sbin",
		...currentPath.split(":"),
	];
	Deno.env.set("PATH", Array.from(new Set(paths.filter(Boolean))).join(":"));
}

async function isRootOnlyNix(): Promise<boolean> {
	if (Deno.build.os !== "linux") return false;
	if (await exists("/run/systemd/system")) return false;
	if (await exists("/nix/var/nix/daemon-socket/socket")) return false;
	return Deno.uid?.() !== 0;
}

async function ensureNixAvailable() {
	const { success } = await runCommand(["nix", "--version"]);
	if (!success) {
		printError("nix not found after bootstrapping PATH");
		Deno.exit(1);
	}
}

async function maybeInstallOsUpdates(opts: RebuildOptions) {
	if (!opts.rebuildOs) return;

	if (Deno.build.os !== "darwin") {
		printWarning("--rebuild-os is only supported on macOS");
		return;
	}

	printInfo("Installing macOS software updates (this may take a while)");
	await runCommand(["sudo", "softwareupdate", "--install", "--all"]);
}

async function maybeUpdateFlake(context: RebuildContext, opts: RebuildOptions) {
	if (!opts.update) return;

	printInfo("Updating flake inputs");
	const updateCommand = withSudoIfNeeded(context, [
		"nix",
		"flake",
		"update",
		"--flake",
		context.flakeDir,
	]);
	const update = await runCommand(updateCommand.args, {
		cwd: context.dotfilesDir,
		env: nixEnv(context),
	});

	if (update.success) {
		printSuccess("Flake lock updated");
	} else {
		printWarning("Flake update failed (continuing)");
	}

	await maybeUpdatePnpmGlobals();
	await maybeUpdateBrew(opts);
}

async function maybeUpdatePnpmGlobals() {
	const found = await commandSucceeds([
		"bash",
		"-lc",
		"command -v pnpm:global:update",
	]);
	if (!found) {
		printWarning(
			"pnpm:global:update not found, skipping managed pnpm global dependency update",
		);
		return;
	}

	printInfo("Updating managed pnpm global dependencies");
	const result = await runCommand(["bash", "-lc", "pnpm:global:update"]);
	if (result.success) {
		printSuccess("Managed pnpm global dependencies updated");
	} else {
		printWarning("Managed pnpm global update failed (continuing)");
	}
}

async function maybeUpdateBrew(opts: RebuildOptions) {
	if (!opts.brew) return;

	if (Deno.build.os !== "darwin") {
		printError("--brew is only supported on macOS");
		Deno.exit(1);
	}

	const found = await commandSucceeds(["bash", "-lc", "command -v brew"]);
	if (!found) {
		printWarning("brew not found, skipping Homebrew cask update");
		return;
	}

	printInfo("Updating Homebrew casks with --greedy (slow)");
	const result = await runCommand(["brew", "upgrade", "--cask", "--greedy"]);
	if (result.success) {
		printSuccess("Homebrew casks updated");
	} else {
		printWarning("Homebrew cask upgrade failed (continuing)");
	}
}

async function maybeCheckFlake(context: RebuildContext, opts: RebuildOptions) {
	if (opts.skipCheck) return;

	printInfo("Checking flake configuration");
	const checkCommand = withSudoIfNeeded(context, [
		"nix",
		"flake",
		"check",
		context.flakeDir,
		"--impure",
	]);
	await runRequired({
		args: checkCommand.args,
		cwd: context.dotfilesDir,
		env: nixEnv(context),
	});
}

async function runRebuild(context: RebuildContext, config: MachineConfig) {
	if (Deno.build.os === "darwin") {
		printInfo("Rebuilding nix-darwin configuration with nh");
		const nhArgs = await nhCommand([
			"darwin",
			"switch",
			context.flakeDir,
			"-H",
			"default",
			"--impure",
		]);

		await runRequired({
			args: ["bash", "-lc", `ulimit -n 10240 && ${shellCommand(nhArgs)}`],
			cwd: context.dotfilesDir,
			env: nixEnv(context),
		});
		printSuccess("Configuration rebuilt successfully");
		printInfo(
			"Both system (darwin) and user (home-manager) configurations have been updated.",
		);
		return;
	}

	printInfo("Rebuilding home-manager configuration with nh");
	const hmConfiguration = `${config.username}@${config.system}`;
	const nhArgs = await nhCommand([
		"home",
		"switch",
		context.flakeDir,
		"-c",
		hmConfiguration,
		"--impure",
	]);
	const rebuildArgs = withSudoIfNeeded(context, nhArgs).args;

	await runRequired({
		args: rebuildArgs,
		cwd: context.dotfilesDir,
		env: {
			...nixEnv(context),
			HOME: Deno.env.get("HOME") ?? "",
			USER: config.username,
		},
	});
	printSuccess("Configuration rebuilt successfully");
	printInfo("Home-manager configuration has been updated.");
}

async function nhCommand(args: string[]): Promise<string[]> {
	if (await commandSucceeds(["bash", "-lc", "command -v nh"])) {
		return ["nh", ...args];
	}

	printInfo("nh not found, using nix run nixpkgs#nh for first-time setup");
	return ["nix", "run", "nixpkgs#nh", "--", ...args];
}

function withSudoIfNeeded(
	context: RebuildContext,
	args: string[],
): CommandSpec {
	return { args: context.rootOnlyNix ? ["sudo", ...args] : args };
}

function nixEnv(context: RebuildContext): Record<string, string> {
	return {
		NIX_USER_CONFIG_DIR: context.nixConfigDir,
	};
}

function printPlan(
	context: RebuildContext,
	config: MachineConfig,
	opts: RebuildOptions,
) {
	const commands: CommandSpec[] = [];

	if (opts.update) {
		commands.push(
			withSudoIfNeeded(context, [
				"nix",
				"flake",
				"update",
				"--flake",
				context.flakeDir,
			]),
		);
	}

	if (!opts.skipCheck) {
		commands.push(
			withSudoIfNeeded(context, [
				"nix",
				"flake",
				"check",
				context.flakeDir,
				"--impure",
			]),
		);
	}

	if (Deno.build.os === "darwin") {
		commands.push({
			args: [
				"nh",
				"darwin",
				"switch",
				context.flakeDir,
				"-H",
				"default",
				"--impure",
			],
		});
	} else {
		commands.push(withSudoIfNeeded(context, [
			"nh",
			"home",
			"switch",
			context.flakeDir,
			"-c",
			`${config.username}@${config.system}`,
			"--impure",
		]));
	}

	printHeader("Rebuild plan");
	for (const command of commands) {
		console.log(formatCommand(command.args));
	}
}

async function runRequired(spec: CommandSpec) {
	const result = await runCommand(spec.args, { cwd: spec.cwd, env: spec.env });
	if (!result.success) {
		printError(
			`Command failed with exit code ${result.code}: ${
				formatCommand(spec.args)
			}`,
		);
		Deno.exit(result.code);
	}
}

async function commandSucceeds(args: string[]): Promise<boolean> {
	try {
		const command = new Deno.Command(args[0], {
			args: args.slice(1),
			stderr: "null",
			stdout: "null",
		});
		return (await command.output()).success;
	} catch {
		return false;
	}
}

async function captureCommand(args: string[], cwd: string): Promise<string> {
	const command = new Deno.Command(args[0], {
		args: args.slice(1),
		cwd,
		stderr: "inherit",
		stdout: "piped",
	});
	const output = await command.output();
	if (!output.success) return "";
	return new TextDecoder().decode(output.stdout).trim();
}

function shellCommand(args: string[]): string {
	return args.map(shellQuote).join(" ");
}

function shellQuote(value: string): string {
	if (/^[A-Za-z0-9_@%+=:,./#-]+$/.test(value)) return value;
	return `'${value.replaceAll("'", `'\\''`)}'`;
}
