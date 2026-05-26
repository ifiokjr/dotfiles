/**
 * `dotfiles groups` — Config group management
 *
 * Provides subcommands for listing, inspecting, deploying, and undeploying
 * configuration groups.
 */

import { Command } from "@cliffy/command";
import {
	discoverGroups,
	loadGroupMetadata,
	printError,
	printHeader,
	printSuccess,
	resolveDotfilesDir,
	runCommand,
} from "../lib/config.ts";

export const groupsCommand = new Command()
	.description(
		"Manage configuration groups — list, inspect, deploy, and undeploy",
	)
	.command(
		"list",
		new Command()
			.description("List available configuration groups")
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();
				const groups = await discoverGroups(dotfilesDir);

				if (groups.length === 0) {
					printError("No configuration groups found in Configs/");
					return;
				}

				printHeader("Available configuration groups");
				for (const group of groups) {
					const meta = await loadGroupMetadata(dotfilesDir, group);
					console.log(`  ${group.padEnd(14)} ${meta.description}`);
				}
			}),
	)
	.command(
		"info",
		new Command()
			.description("Show detailed information about a configuration group")
			.arguments("<group:string>")
			.action(async (_opts, group: string) => {
				const dotfilesDir = await resolveDotfilesDir();
				const groups = await discoverGroups(dotfilesDir);

				if (!groups.includes(group)) {
					printError(`Unknown configuration group: ${group}`);
					console.log(`Available groups: ${groups.join(", ")}`);
					Deno.exit(1);
				}

				const meta = await loadGroupMetadata(dotfilesDir, group);

				printHeader(`Group: ${group}`);
				console.log(`  Description: ${meta.description}`);
				console.log(
					`  Platforms:   ${
						meta.platforms.length > 0 ? meta.platforms.join(", ") : "all"
					}`,
				);
				console.log(`  Phase:       ${meta.phase}`);
				console.log(
					`  Presets:     ${
						meta.presets.length > 0 ? meta.presets.join(", ") : "none"
					}`,
				);
				console.log(
					`  Depends on:  ${
						meta.dependsOn.length > 0 ? meta.dependsOn.join(", ") : "none"
					}`,
				);
			}),
	)
	.command(
		"deploy",
		new Command()
			.description("Deploy specific configuration groups")
			.arguments("<groups...:string>")
			.option("--force", "Force overwrite existing symlinks")
			.action(async (_opts, ...groups: string[]) => {
				const dotfilesDir = await resolveDotfilesDir();

				// Phase 1: shell out to the setup script with --groups
				const setupScript = `${dotfilesDir}/setup`;
				const args = ["--groups", groups.join(","), "--no-confirm"];

				const { code, success } = await runCommand([setupScript, ...args], {
					cwd: dotfilesDir,
				});

				if (!success) {
					printError(`Deploy failed with exit code ${code}`);
					Deno.exit(code);
				}

				printSuccess(`Deployed groups: ${groups.join(", ")}`);
			}),
	)
	.command(
		"undeploy",
		new Command()
			.description("Remove configuration groups and run cleanup hooks")
			.arguments("<groups...:string>")
			.option("--no-hooks", "Skip running cleanup hooks (only remove symlinks)")
			.action(async (opts, ...groups: string[]) => {
				const dotfilesDir = await resolveDotfilesDir();

				const knownGroups = await discoverGroups(dotfilesDir);
				for (const group of groups) {
					if (!knownGroups.includes(group)) {
						printError(`Unknown configuration group: ${group}`);
						console.log(`Available groups: ${knownGroups.join(", ")}`);
						Deno.exit(1);
					}
				}

				const subcommand = opts.hooks ? "unset" : "rm";
				const args = ["tuckr", subcommand, ...groups];

				const { code, success } = await runCommand(args, {
					cwd: dotfilesDir,
				});

				if (!success) {
					printError(`Undeploy failed with exit code ${code}`);
					Deno.exit(code);
				}

				const action = opts.hooks ? "Undeployed" : "Removed symlinks for";
				printSuccess(`${action} groups: ${groups.join(", ")}`);
			}),
	)
	.command(
		"status",
		new Command()
			.description("Show deployment status of all groups")
			.action(async () => {
				// Phase 1: delegate to tuckr status
				const dotfilesDir = await resolveDotfilesDir();
				const { code, success } = await runCommand(["tuckr", "status"], {
					cwd: dotfilesDir,
				});

				if (!success) {
					printError(`Status check failed with exit code ${code}`);
					Deno.exit(code);
				}
			}),
	);
