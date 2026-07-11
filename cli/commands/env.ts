/**
 * `dotfiles env` — Environment management
 *
 * Provides subcommands for managing environment setup and secrets.
 * `env setup` runs the setup:env script.
 * `env secrets` delegates to Monosecret CLI for checking, running,
 * and managing secrets.
 */

import { Command } from "@cliffy/command";
import {
	printError,
	printSuccess,
	resolveDotfilesDir,
	runCommand,
} from "../lib/config.ts";

export const envCommand = new Command()
	.description("Manage environment configuration and secrets")
	.command(
		"setup",
		new Command()
			.description("Manage the ~/.env.dotfiles fallback (Monosecret)")
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();
				const script = `${dotfilesDir}/Configs/scripts/.local/bin/setup:env`;
				const { code, success } = await runCommand([script], {
					cwd: dotfilesDir,
				});
				if (!success) Deno.exit(code);
			}),
	)
	.command(
		"secrets",
		new Command()
			.description("Manage secrets via Monosecret")
			.command(
				"check",
				new Command()
					.description("Check if all required secrets are available")
					.action(async () => {
						const dotfilesDir = await resolveDotfilesDir();
						const specFile =
							`${dotfilesDir}/Configs/monosecret/monosecret.toml`;
						const { code, success } = await runCommand(
							[
								"monosecret",
								"-f",
								specFile,
								"--reason",
								"dotfiles env secrets check",
								"check",
							],
							{ cwd: dotfilesDir },
						);
						if (!success) {
							printError(`Secret check failed (exit ${code})`);
							Deno.exit(code);
						}
						printSuccess("All required secrets are available");
					}),
			)
			.command(
				"run",
				new Command()
					.description(
						"Run a command with secrets injected into the environment",
					)
					.arguments("<command...:string>")
					.option(
						"--include <secrets...:string>",
						"Only include specific secrets (comma-separated or repeated)",
					)
					.action(async (opts, ...command: string[]) => {
						const dotfilesDir = await resolveDotfilesDir();
						const specFile =
							`${dotfilesDir}/Configs/monosecret/monosecret.toml`;
						const args = [
							"monosecret",
							"-f",
							specFile,
							"--reason",
							"dotfiles env secrets run",
							"run",
						];
						if (opts.include?.length) {
							for (const inc of opts.include) {
								args.push("--include", inc);
							}
						}
						args.push("--", ...command);

						const { code, success } = await runCommand(args, {
							cwd: dotfilesDir,
						});
						if (!success) Deno.exit(code);
					}),
			)
			.command(
				"get",
				new Command()
					.description("Get a specific secret value")
					.arguments("<name:string>")
					.action(async (_opts, name: string) => {
						const dotfilesDir = await resolveDotfilesDir();
						const specFile =
							`${dotfilesDir}/Configs/monosecret/monosecret.toml`;
						const { code, success } = await runCommand(
							[
								"monosecret",
								"-f",
								specFile,
								"--reason",
								"dotfiles env secrets get",
								"get",
								name,
							],
							{ cwd: dotfilesDir },
						);
						if (!success) Deno.exit(code);
					}),
			)
			.command(
				"set",
				new Command()
					.description("Set a specific secret value")
					.arguments("<name:string>")
					.action(async (_opts, name: string) => {
						const dotfilesDir = await resolveDotfilesDir();
						const specFile =
							`${dotfilesDir}/Configs/monosecret/monosecret.toml`;
						const { code, success } = await runCommand(
							[
								"monosecret",
								"-f",
								specFile,
								"--reason",
								"dotfiles env secrets set",
								"set",
								name,
							],
							{ cwd: dotfilesDir },
						);
						if (!success) Deno.exit(code);
					}),
			),
	);
