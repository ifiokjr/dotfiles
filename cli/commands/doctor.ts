/**
 * `dotfiles doctor` — Preflight health checks.
 *
 * Runs the same checks as `setup --doctor`, but natively in TypeScript so
 * users can inspect and evolve the logic through the CLI codebase.
 */

import { Command } from "@cliffy/command";
import { dirname, join } from "@std/path";
import {
	commandExists,
	detectPlatform,
	type Platform,
	printError,
	printHeader,
	printInfo,
	printSuccess,
	printWarning,
	resolveDotfilesDir,
} from "../lib/config.ts";

/** Minimum free disk space recommended for Nix builds. */
const MIN_HOME_DISK_BYTES = 10 * 1024 * 1024 * 1024;

/** Mutable diagnostic counters shared by individual checks. */
interface DoctorState {
	problems: number;
	warnings: number;
}

/** Result from running a subprocess without showing its output. */
interface QuietCommandResult {
	stdout: string;
	success: boolean;
}

/** Options needed by preflight checks that depend on paths/platform. */
interface DoctorContext {
	dotfilesDir: string;
	homeDir: string;
	platform: Platform;
}

/** Run a subprocess and capture stdout while hiding noisy command output. */
async function runQuiet(
	command: string,
	args: string[] = [],
): Promise<QuietCommandResult> {
	try {
		const { stdout, success } = await new Deno.Command(command, {
			args,
			stdout: "piped",
			stderr: "null",
		}).output();

		return {
			stdout: new TextDecoder().decode(stdout),
			success,
		};
	} catch {
		return { stdout: "", success: false };
	}
}

/** Check that a command exists and report a blocking problem when missing. */
async function requireCommand(
	name: string,
	missingMessage: string,
	state: DoctorState,
): Promise<boolean> {
	if (await commandExists(name)) {
		printSuccess(`${name} available`);

		return true;
	}

	printError(missingMessage);
	state.problems++;

	return false;
}

/** Check Git availability with platform-specific fallback guidance. */
async function checkGit(platform: Platform, state: DoctorState): Promise<void> {
	if (await commandExists("git")) {
		printSuccess("Git available");

		return;
	}

	if (platform === "macos") {
		printWarning(
			"Git is not runnable yet; setup can fall back to Nix, but Command Line Tools may still be missing",
		);
		state.warnings++;

		return;
	}

	printWarning(
		"Git is not installed; setup can install it temporarily after Nix",
	);
	state.warnings++;
}

/** Check whether sudo exists and whether it can currently run non-interactively. */
async function checkSudo(state: DoctorState): Promise<void> {
	if (!await commandExists("sudo")) {
		printWarning("sudo not found; some setup paths may not work");
		state.warnings++;

		return;
	}

	const result = await runQuiet("sudo", ["-n", "true"]);

	if (result.success) {
		printSuccess("sudo available without prompting");

		return;
	}

	printInfo("sudo available (setup may prompt when applying system changes)");
}

/** Check whether Nix is already installed and responding. */
async function checkNix(state: DoctorState): Promise<void> {
	if (!await commandExists("nix")) {
		printInfo(
			"Nix not installed (setup can install it unless --skip-nix is used)",
		);

		return;
	}

	const result = await runQuiet("nix", ["--version"]);

	if (result.success) {
		printSuccess("Nix installed and responding");

		return;
	}

	printWarning("nix command found but not responding");
	state.warnings++;
}

/** Check macOS Command Line Tools, which are commonly needed before Git works. */
async function checkXcodeCommandLineTools(
	platform: Platform,
	state: DoctorState,
): Promise<void> {
	if (platform !== "macos") {
		return;
	}

	const result = await runQuiet("xcode-select", ["-p"]);

	if (result.success) {
		printSuccess("Xcode Command Line Tools installed");

		return;
	}

	printWarning("Xcode Command Line Tools are not installed yet");
	state.warnings++;
}

/** Return available bytes for a path using portable POSIX `df -Pk` output. */
async function availableDiskBytes(path: string): Promise<number | null> {
	const result = await runQuiet("df", ["-Pk", path]);

	if (!result.success) {
		return null;
	}

	const lines = result.stdout.trim().split("\n");

	if (lines.length < 2) {
		return null;
	}

	const availableKb = Number.parseInt(lines[1].split(/\s+/)[3], 10);

	if (Number.isNaN(availableKb)) {
		return null;
	}

	return availableKb * 1024;
}

/** Warn when the home filesystem is likely too small for larger Nix builds. */
async function checkDiskSpace(
	homeDir: string,
	state: DoctorState,
): Promise<void> {
	const freeBytes = await availableDiskBytes(homeDir);

	if (freeBytes === null) {
		printInfo("Could not determine free disk space");

		return;
	}

	if (freeBytes >= MIN_HOME_DISK_BYTES) {
		printSuccess("Sufficient free disk space detected");

		return;
	}

	const freeGiB = (freeBytes / (1024 * 1024 * 1024)).toFixed(1);

	printWarning(
		`Less than 10 GiB free in the home filesystem (${freeGiB} GiB); large Nix builds may fail`,
	);
	state.warnings++;
}

/** Warn when GitHub API/downloads may be rate-limited. */
function checkGitHubToken(state: DoctorState): void {
	if (Deno.env.get("GITHUB_TOKEN")) {
		printSuccess("GITHUB_TOKEN is set");

		return;
	}

	printWarning(
		"GITHUB_TOKEN is not set; GitHub-backed fetches may be rate limited",
	);
	state.warnings++;
}

/** Confirm setup can create the dotfiles and tuckr symlink parent directories. */
async function checkWritableDirectories(
	context: DoctorContext,
	state: DoctorState,
): Promise<void> {
	const dotfilesParent = dirname(context.dotfilesDir);
	const tuckrParent = dirname(
		resolveTuckrPath(context.homeDir, context.platform),
	);

	await checkWritableDirectory(
		dotfilesParent,
		"Dotfiles parent directory",
		state,
	);

	await checkWritableDirectory(
		tuckrParent,
		"Tuckr symlink parent directory",
		state,
	);
}

/** Check whether a directory can be created or written. */
async function checkWritableDirectory(
	path: string,
	label: string,
	state: DoctorState,
): Promise<void> {
	try {
		await Deno.mkdir(path, { recursive: true });
		printSuccess(`${label} is writable: ${path}`);
	} catch {
		printError(`Cannot write to ${label.toLowerCase()}: ${path}`);
		state.problems++;
	}
}

/** Resolve the platform-specific tuckr symlink path. */
function resolveTuckrPath(homeDir: string, platform: Platform): string {
	if (platform === "macos") {
		return join(homeDir, "Library/Application Support/dotfiles");
	}

	return join(homeDir, ".config/dotfiles");
}

/** Check whether GitHub is reachable for bootstrap downloads and repository fetches. */
async function checkGitHubReachability(state: DoctorState): Promise<void> {
	const result = await runQuiet("curl", [
		"--head",
		"--silent",
		"--fail",
		"--location",
		"--max-time",
		"10",
		"https://github.com",
	]);

	if (result.success) {
		printSuccess("GitHub reachable");

		return;
	}

	printWarning("GitHub could not be reached during the preflight check");
	state.warnings++;
}

/** Print the final doctor result and exit non-zero for blocking issues. */
function printDoctorSummary(state: DoctorState): void {
	console.log("");

	if (state.problems > 0) {
		const issueText = pluralize("blocking issue", state.problems);
		const warningText = pluralize("warning", state.warnings);

		printError(
			`Doctor found ${state.problems} ${issueText} and ${state.warnings} ${warningText}`,
		);
		Deno.exit(1);
	}

	if (state.warnings > 0) {
		const warningText = pluralize("warning", state.warnings);

		printWarning(
			`Doctor found ${state.warnings} ${warningText}, but no blocking issues`,
		);

		return;
	}

	printSuccess("Doctor found no obvious blockers");
}

/** Return a singular/plural label for a count. */
function pluralize(label: string, count: number): string {
	return count === 1 ? label : `${label}s`;
}

export const doctorCommand = new Command()
	.description("Run preflight checks without changing the machine")
	.action(async () => {
		const dotfilesDir = await resolveDotfilesDir();
		const homeDir = Deno.env.get("HOME") ?? "~";
		const platform = detectPlatform();
		const state: DoctorState = { problems: 0, warnings: 0 };
		const context: DoctorContext = { dotfilesDir, homeDir, platform };

		printHeader("Dotfiles Doctor");
		printSuccess(`Platform supported: ${platform}`);

		// === Required Tools ===
		await requireCommand(
			"curl",
			"curl is required for bootstrap and is not installed",
			state,
		);

		await checkGit(platform, state);

		await checkSudo(state);

		await checkNix(state);

		// === Platform Checks ===
		await checkXcodeCommandLineTools(platform, state);

		// === System Capacity ===
		await checkDiskSpace(homeDir, state);

		// === Environment ===
		checkGitHubToken(state);

		// === Filesystem ===
		await checkWritableDirectories(context, state);

		// === Network ===
		await checkGitHubReachability(state);

		printDoctorSummary(state);
	});
