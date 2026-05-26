/**
 * `dotfiles setup` — Initial installation
 *
 * Shells out to the existing bash setup script.
 * In Phase 2, this will be reimplemented natively in TypeScript.
 */

import { Command } from "@cliffy/command";
import { resolveDotfilesDir, runCommand } from "../lib/config.ts";

export const setupCommand = new Command()
	.description(
		"Initial dotfiles setup — install Nix, clone repo, deploy groups",
	)
	.option(
		"--preset <preset:string>",
		"Use a named setup preset: core, dev, workstation, ci",
		{
			default: "core",
		},
	)
	.option(
		"--groups <groups:string>",
		"Deploy specific groups (comma-separated; overrides preset)",
	)
	.option("--lite", "Force CLI-focused mode and skip GUI-heavy applications")
	.option("--skip-nix", "Skip Nix installation (use if already installed)")
	.option("--doctor", "Run preflight checks without changing the machine")
	.option("--dry-run", "Print the setup plan and exit without making changes")
	.option("--no-confirm", "Run headlessly without interactive prompts")
	.option("--confirm", "Run with confirmation prompts (default)", {
		default: true,
	})
	.option("--resume", "Resume from the last failed setup phase or group")
	.option(
		"--from <target:string>",
		"Resume from a specific phase or deployment group",
	)
	.option(
		"--cwd <path:string>",
		"Clone dotfiles to PATH (default: ~/Developer/.dotfiles)",
	)
	.action(async (opts) => {
		const dotfilesDir = await resolveDotfilesDir();
		const setupScript = `${dotfilesDir}/setup`;

		const args: string[] = [];

		if (opts.preset) args.push("--preset", opts.preset);
		if (opts.groups) args.push("--groups", opts.groups);
		if (opts.lite) args.push("--lite");
		if (opts.skipNix) args.push("--skip-nix");
		if (opts.doctor) args.push("--doctor");
		if (opts.dryRun) args.push("--dry-run");
		if (!opts.confirm) args.push("--no-confirm");
		if (opts.resume) args.push("--resume");
		if (opts.from) args.push("--from", opts.from);
		if (opts.cwd) args.push("--cwd", opts.cwd);

		console.log(`Running: ${setupScript} ${args.join(" ")}`);
		const { code, success } = await runCommand([setupScript, ...args]);

		if (!success) {
			Deno.exit(code);
		}
	});
