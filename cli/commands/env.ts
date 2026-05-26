/**
 * `dotfiles env` — Environment management
 */

import { Command } from "@cliffy/command";
import { resolveDotfilesDir, runCommand } from "../lib/config.ts";

export const envCommand = new Command()
	.description("Manage environment configuration and secrets")
	.command(
		"setup",
		new Command()
			.description("Manage the ~/.env.dotfiles fallback (SecretSpec)")
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();
				const script = `${dotfilesDir}/Configs/scripts/.local/bin/setup:env`;
				const { code, success } = await runCommand([script], {
					cwd: dotfilesDir,
				});
				if (!success) Deno.exit(code);
			}),
	);
