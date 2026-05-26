/**
 * `dotfiles uninstall` — Full uninstall
 */

import { Command } from "@cliffy/command";
import { printError, resolveDotfilesDir, runCommand } from "../lib/config.ts";

export const uninstallCommand = new Command()
	.description("Completely remove dotfiles installation (nix, symlinks, state)")
	.option("--keep-nix", "Skip Nix uninstallation")
	.option("--no-confirm", "Run without interactive prompts")
	.action(async (opts) => {
		const dotfilesDir = await resolveDotfilesDir();
		const script =
			`${dotfilesDir}/Configs/scripts/.local/bin/uninstall:dotfiles`;

		const args: string[] = [];
		if (opts.keepNix) args.push("--keep-nix");
		if (!opts.confirm) args.push("--no-confirm");

		const { code, success } = await runCommand([script, ...args], {
			cwd: dotfilesDir,
		});

		if (!success) {
			printError(`Uninstall failed (exit code ${code})`);
			Deno.exit(code);
		}
	});
