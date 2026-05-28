/**
 * `dotfiles rebuild` — Rebuild Nix configuration and redeploy groups
 *
 * Phase 1: Shells out to the nushell rebuild script.
 * Phase 2: Will be reimplemented natively in TypeScript.
 */

import { Command } from "@cliffy/command";
import {
	findExecutable,
	printError,
	printHeader,
	resolveDotfilesDir,
	runCommand,
} from "../lib/config.ts";

export const rebuildCommand = new Command()
	.description(
		"Rebuild system configuration (nix-darwin switch or home-manager switch)",
	)
	.option(
		"--groups <groups:string>",
		"Only rebuild specific groups (comma-separated)",
	)
	.option("--lite", "Override lite mode for this rebuild")
	.option("--dry-run", "Show the rebuild plan without executing")
	.action(async (opts) => {
		const dotfilesDir = await resolveDotfilesDir();

		// Try to find the rebuild script
		const rebuildScript = await findExecutable("rebuild");
		const fallbackScript = `${dotfilesDir}/Configs/scripts/.local/bin/rebuild`;

		const script = rebuildScript ?? fallbackScript;
		const args: string[] = [];

		if (opts.groups) args.push("--groups", opts.groups);
		if (opts.lite) args.push("--lite");
		if (opts.dryRun) args.push("--dry-run");

		printHeader("Rebuilding system configuration");
		const { code, success } = await runCommand([script, ...args], {
			cwd: dotfilesDir,
			env: {
				DOTFILES_CLI: "1",
			},
		});

		if (!success) {
			printError(`Rebuild failed with exit code ${code}`);
			Deno.exit(code);
		}
	});
