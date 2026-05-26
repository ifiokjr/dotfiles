/**
 * `dotfiles reset` — Uninstall + re-setup from scratch
 */

import { Command } from "@cliffy/command";
import { printError, resolveDotfilesDir, runCommand } from "../lib/config.ts";

export const resetCommand = new Command()
	.description("Uninstall and re-setup dotfiles from scratch")
	.option("--no-confirm", "Run without interactive prompts")
	.action(async (opts) => {
		const dotfilesDir = await resolveDotfilesDir();
		const script = `${dotfilesDir}/Configs/scripts/.local/bin/reset:dotfiles`;

		const args: string[] = [];
		if (!opts.confirm) args.push("--no-confirm");

		const { code, success } = await runCommand([script, ...args], {
			cwd: dotfilesDir,
		});

		if (!success) {
			printError(`Reset failed (exit code ${code})`);
			Deno.exit(code);
		}
	});
