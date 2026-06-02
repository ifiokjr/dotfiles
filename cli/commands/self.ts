/**
 * `dotfiles self` — Manage the dotfiles CLI binary itself.
 */

import { Command } from "@cliffy/command";
import { ensureDir } from "@std/fs";
import { dirname, join } from "@std/path";
import {
	printError,
	printHeader,
	printInfo,
	printSuccess,
	printWarning,
	resolveDotfilesDir,
	runCommand,
} from "../lib/config.ts";

export interface InstallDotfilesCliOptions {
	binDir?: string;
	dotfilesDir?: string;
}

export const selfCommand = new Command()
	.description("Manage the dotfiles CLI binary")
	.command(
		"install",
		new Command()
			.description("Compile and install dotfiles/dot into ~/.local/bin")
			.option("--bin-dir <dir:string>", "Installation directory", {
				default: defaultBinDir(),
			})
			.action(async (opts: { binDir: string }) => {
				await installDotfilesCli({ binDir: opts.binDir });
			}),
	);

export async function installDotfilesCli(opts: InstallDotfilesCliOptions = {}) {
	const dotfilesDir = opts.dotfilesDir ?? await resolveDotfilesDir();
	const binDir = opts.binDir ?? defaultBinDir();
	const cliDir = join(dotfilesDir, "cli");
	const repoBinary = join(dotfilesDir, "Configs/scripts/.local/bin/dotfiles");
	const installedBinary = join(binDir, "dotfiles");
	const installedAlias = join(binDir, "dot");

	printHeader("Installing dotfiles CLI");
	printInfo("Compiling dotfiles binary from current source tree");

	const compile = await runCommand([
		"deno",
		"compile",
		"--allow-all",
		"--output",
		repoBinary,
		"main.ts",
	], { cwd: cliDir });

	if (!compile.success) {
		printError(`Failed to compile dotfiles CLI (exit code ${compile.code})`);
		Deno.exit(compile.code);
	}

	await ensureDir(binDir);
	await linkOrCopy(repoBinary, installedBinary);
	await replaceSymlink(installedAlias, installedBinary);
	await installCompletions(installedAlias);

	printSuccess(`Installed dotfiles: ${installedBinary}`);
	printSuccess(`Installed dot alias: ${installedAlias}`);
}

function defaultBinDir(): string {
	return join(Deno.env.get("HOME") ?? ".", ".local/bin");
}

async function installCompletions(dotBinary: string) {
	await installBashCompletions(dotBinary);
	await installNushellCompletions(dotBinary);
}

async function installBashCompletions(dotBinary: string) {
	const home = Deno.env.get("HOME");
	if (!home) return;

	const completionDir = join(home, ".local/share/bash-completion/completions");
	const dotCompletion = join(completionDir, "dot");
	const dotfilesCompletion = join(completionDir, "dotfiles");

	await ensureDir(completionDir);
	const result = await runCommand([dotBinary, "completion", "bash"], {
		stdout: "piped",
	});

	if (!result.success || result.stdout === undefined) {
		printWarning("Could not generate bash completions");
		return;
	}

	await Deno.writeTextFile(dotCompletion, result.stdout);
	await replaceSymlink(dotfilesCompletion, dotCompletion);
	printSuccess(`Updated bash completions: ${dotCompletion}`);
}

async function installNushellCompletions(dotBinary: string) {
	const result = await runCommand([
		"nu",
		"-c",
		'$nu.data-dir | path join "vendor/autoload"',
	], { stdout: "piped" });

	if (!result.success || result.stdout === undefined) {
		printWarning("Could not resolve Nushell vendor autoload directory");
		return;
	}

	const autoloadDir = result.stdout.trim();
	if (!autoloadDir) return;

	const completions = await runCommand([dotBinary, "completion", "nushell"], {
		stdout: "piped",
	});

	if (!completions.success || completions.stdout === undefined) {
		printWarning("Could not generate Nushell completions");
		return;
	}

	await ensureDir(autoloadDir);
	const completionFile = join(autoloadDir, "dot-completions.nu");
	await Deno.writeTextFile(completionFile, completions.stdout);
	printSuccess(`Updated Nushell completions: ${completionFile}`);
}

async function linkOrCopy(source: string, destination: string) {
	try {
		await replaceSymlink(destination, source);
	} catch {
		await Deno.copyFile(source, destination);
		await Deno.chmod(destination, 0o755);
	}
}

async function replaceSymlink(path: string, target: string) {
	try {
		await Deno.remove(path);
	} catch (error) {
		if (!(error instanceof Deno.errors.NotFound)) throw error;
	}

	await ensureDir(dirname(path));
	await Deno.symlink(target, path);
}
