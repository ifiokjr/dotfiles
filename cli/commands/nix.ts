/**
 * `dotfiles nix` — Direct nix operations
 */

import { Command } from "@cliffy/command";
import {
	printError,
	printHeader,
	resolveDotfilesDir,
	runCommand,
} from "../lib/config.ts";

export const nixCommand = new Command()
	.description("Manage nix configuration directly")
	.command(
		"switch",
		new Command()
			.description("Run nix-darwin switch or home-manager switch")
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();
				// Delegate to the nix post-hook script directly
				const script = `${dotfilesDir}/Configs/nix/.config/nix/apply.sh`;
				printHeader("Running nix switch");
				const { code, success } = await runCommand([script], {
					cwd: dotfilesDir,
				});
				if (!success) {
					printError(`Nix switch failed (exit code ${code})`);
					Deno.exit(code);
				}
			}),
	)
	.command(
		"profile",
		new Command()
			.description("Manage nix profile packages")
			.command(
				"add",
				new Command()
					.description("Add a package to the nix profile")
					.arguments("<package:string>")
					.action(async (_opts, pkg: string) => {
						const { code, success } = await runCommand([
							"nix",
							"profile",
							"add",
							`nixpkgs#${pkg}`,
						]);
						if (!success) {
							printError(`Failed to add ${pkg} (exit code ${code})`);
							Deno.exit(code);
						}
					}),
			)
			.command(
				"remove",
				new Command()
					.description("Remove a package from the nix profile")
					.arguments("<package:string>")
					.action(async (_opts, pkg: string) => {
						const { code, success } = await runCommand([
							"nix",
							"profile",
							"remove",
							"--regex",
							`.*${pkg}.*`,
						]);
						if (!success) {
							printError(`Failed to remove ${pkg} (exit code ${code})`);
							Deno.exit(code);
						}
					}),
			),
	);
