/**
 * `dotfiles env` — Environment management
 *
 * Provides subcommands for managing environment setup and secrets.
 * `env setup` runs the setup:env script.
 * `env secrets` delegates to SecretSpec CLI for checking, running,
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
			.description("Manage the ~/.env.dotfiles fallback (SecretSpec)")
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
			.description("Manage secrets via SecretSpec")
			.command(
				"check",
				new Command()
					.description("Check if all required secrets are available")
					.action(async () => {
						const dotfilesDir = await resolveDotfilesDir();
						const specFile =
							`${dotfilesDir}/Configs/secretspec/secretspec.toml`;
						const { code, success } = await runCommand(
							["secretspec", "check", "-f", specFile],
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
							`${dotfilesDir}/Configs/secretspec/secretspec.toml`;
						const args = ["secretspec", "run", "-f", specFile];
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
							`${dotfilesDir}/Configs/secretspec/secretspec.toml`;
						const { code, success } = await runCommand(
							["secretspec", "get", "-f", specFile, name],
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
							`${dotfilesDir}/Configs/secretspec/secretspec.toml`;
						const { code, success } = await runCommand(
							["secretspec", "set", "-f", specFile, name],
							{ cwd: dotfilesDir },
						);
						if (!success) Deno.exit(code);
					}),
			),
	);
