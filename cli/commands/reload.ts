/**
 * `dotfiles reload` — Reload tuckr configuration groups
 *
 * Discovers all config groups, filters by platform, and re-applies symlinks.
 * The nix group always uses `tuckr add --only-files`, preventing its post-hook
 * from rebuilding packages or modifying the tracked flake.lock while ensuring
 * every Nix file is linked by Tuckr.
 *
 * Reimplements the nushell tuckr:reload script natively in TypeScript for
 * type safety, discoverability, and proper flag handling.
 *
 * Groups are deployed in order: nix first, then regular groups alphabetically,
 * then late groups (nushell, helix).
 */

import { Command } from "@cliffy/command";
import {
	commandExists,
	detectPlatform,
	discoverGroups,
	printError,
	printHeader,
	printInfo,
	printSuccess,
	printWarning,
	resolveDotfilesDir,
	runCommand,
} from "../lib/config.ts";

/** Groups whose hooks are safe to run during a symlink-only reload. */
const RELOAD_HOOK_GROUPS = ["nushell"];

/** Groups processed first regardless of alphabetical order. */
const PRIMARY_GROUPS = ["nix"];

/** Groups processed last regardless of alphabetical order. */
const LATE_GROUPS = ["nushell", "helix"];

/** Platform suffixes used by tuckr for platform-specific groups. */
const PLATFORM_SUFFIXES = ["_macos", "_linux", "_bsd", "_windows"] as const;

/** The platform suffix that matches the current OS. */
function platformSuffix(): string {
	switch (detectPlatform()) {
		case "macos":
			return "_macos";
		case "linux":
			return "_linux";
		default:
			return "";
	}
}

/** Check if a group name has a platform suffix. */
function isPlatformGroup(group: string): boolean {
	return PLATFORM_SUFFIXES.some((suffix) => group.endsWith(suffix));
}

/** Check if a platform-specific group matches the current platform. */
function matchesPlatform(group: string): boolean {
	const suffix = platformSuffix();
	if (!suffix) return false;
	return group.endsWith(suffix);
}

/** Select a reload-safe Tuckr operation for a group. */
export function reloadSubcommand(group: string): "add" | "set" {
	return RELOAD_HOOK_GROUPS.includes(group) ? "set" : "add";
}

/** Return group-specific flags needed for a symlink-only reload. */
export function reloadGroupArgs(group: string): string[] {
	return group === "nix" ? ["--only-files"] : [];
}

/**
 * Order groups for deployment: primary → regular → late.
 * Within each bucket, preserve order.
 */
function orderGroups(groups: string[]): string[] {
	const primary = groups.filter((g) => PRIMARY_GROUPS.includes(g));
	const late = groups.filter((g) => LATE_GROUPS.includes(g));
	const regular = groups.filter(
		(g) => !PRIMARY_GROUPS.includes(g) && !LATE_GROUPS.includes(g),
	);
	return [...primary, ...regular, ...late];
}

/** Resolve the tuckr dotfiles directory (platform-specific). */
function resolveTuckrDir(): string {
	const home = Deno.env.get("HOME") ?? "~";
	if (detectPlatform() === "macos") {
		return `${home}/Library/Application Support/dotfiles`;
	}
	return `${home}/.config/dotfiles`;
}

export const reloadCommand = new Command()
	.description(
		"Reload tuckr configuration groups (non-destructive, re-applies symlinks)",
	)
	.option(
		"--group <group:string>",
		"Reload a single group instead of all groups",
	)
	.option("--force", "Overwrite existing files and auto-accept all prompts")
	.option(
		"--adopt",
		"Adopt conflicting files (overwrite repo with system version)",
	)
	.option("--dry-run", "Print what would happen without changing files")
	.action(async (opts) => {
		const dotfilesDir = await resolveDotfilesDir();
		const tuckrDir = resolveTuckrDir();

		// Verify tuckr dotfiles location exists
		try {
			await Deno.stat(tuckrDir);
		} catch {
			printError(`Tuckr dotfiles location not found: ${tuckrDir}`);
			printWarning("Run setup-tuckr-symlink.sh first.");
			Deno.exit(1);
		}

		// Check that tuckr is available
		if (!(await commandExists("tuckr"))) {
			printError("tuckr is not installed or not on PATH");
			Deno.exit(1);
		}

		// Discover and filter groups
		const allGroups = await discoverGroups(dotfilesDir);
		if (allGroups.length === 0) {
			printWarning("No configuration groups found in Configs directory");
			return;
		}

		const platformGroups = allGroups.filter((group) => {
			if (isPlatformGroup(group)) {
				return matchesPlatform(group);
			}
			return true;
		});

		// Filter to a single group if --group was specified
		const targetGroups = opts.group
			? platformGroups.includes(opts.group) ? [opts.group] : (() => {
				printError(`Unknown configuration group: ${opts.group}`);
				console.log(
					`Available groups: ${platformGroups.join(", ")}`,
				);
				Deno.exit(1);
			})()
			: platformGroups;

		if (targetGroups.length === 0) {
			printWarning("No matching groups found for current platform");
			return;
		}

		const ordered = orderGroups(targetGroups);

		// Show status first
		printHeader("Tuckr Config Reload");
		console.log("");
		printInfo(`Location: ${tuckrDir}`);
		printInfo(`Groups: ${ordered.join(", ")}`);
		console.log("");

		// Show current status
		printInfo("Current tuckr status:");
		await runCommand(["tuckr", "status"], { cwd: dotfilesDir });
		console.log("");

		// Build tuckr args
		const tuckrArgs: string[] = [];
		if (opts.dryRun) tuckrArgs.push("--dry-run");
		if (opts.force) {
			tuckrArgs.push("--force");
			tuckrArgs.push("--assume-yes");
		}
		if (opts.adopt) tuckrArgs.push("--adopt");

		// Deploy each group with the appropriate tuckr subcommand
		for (const group of ordered) {
			const subcommand = reloadSubcommand(group);
			const groupArgs = reloadGroupArgs(group);
			const allArgs = [...tuckrArgs, ...groupArgs];
			const fullArgs = ["tuckr", subcommand, ...allArgs, group];

			if (opts.dryRun) {
				printInfo(
					`[dry-run] ${subcommand} ${allArgs.join(" ")} ${group}`,
				);
			} else {
				const label = subcommand === "set"
					? "with reload-safe hooks"
					: "symlinks only";
				printInfo(`Reloading group: ${group} — ${label}...`);

				const { code, success } = await runCommand(fullArgs, {
					cwd: dotfilesDir,
				});

				if (!success) {
					printWarning(`Failed to reload group: ${group} (exit ${code})`);
				} else {
					printSuccess(`Group reloaded: ${group}`);
				}
			}
		}

		console.log("");
		printSuccess("Tuckr reload complete!");
	});
