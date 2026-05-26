/**
 * `dotfiles machine` — Machine.nix management
 *
 * Provides subcommands for reading and modifying machine.nix settings
 * like lite mode, desktop mode, always-on mode, and presets.
 *
 * This is a Phase 1 native implementation — it reads and writes the
 * machine.nix file directly (no shell-out needed).
 */

import { Command } from "@cliffy/command";
import {
	MACHINE_PRESETS,
	machineConfigPath,
	printError,
	printInfo,
	printSuccess,
	resolveDotfilesDir,
	resolveNixConfigDir,
	runCommand,
} from "../lib/config.ts";

export const machineCommand = new Command()
	.description("Manage machine.nix — inspect and modify system configuration")
	.command(
		"config",
		new Command()
			.description("Print current machine.nix configuration")
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();
				const nixDir = await resolveNixConfigDir(dotfilesDir);
				const configPath = machineConfigPath(nixDir);

				try {
					const content = await Deno.readTextFile(configPath);
					console.log(content);
				} catch {
					printError(`machine.nix not found at: ${configPath}`);
					printInfo(
						"Run 'dotfiles setup' or 'dotfiles machine regenerate' to create it.",
					);
					Deno.exit(1);
				}
			}),
	)
	.command(
		"set-lite",
		new Command()
			.description("Set lite mode in machine.nix")
			.arguments("<value:string>")
			.action(async (_opts, value: string) => {
				const enabled = parseBool(value);
				if (enabled === null) {
					printError("Value must be 'on', 'off', 'true', or 'false'");
					Deno.exit(1);
				}
				await setMachineNixField("lite", enabled);
			}),
	)
	.command(
		"set-desktop",
		new Command()
			.description("Set desktop mode in machine.nix")
			.arguments("<value:string>")
			.action(async (_opts, value: string) => {
				const enabled = parseBool(value);
				if (enabled === null) {
					printError("Value must be 'on', 'off', 'true', or 'false'");
					Deno.exit(1);
				}
				await setMachineNixField("isDesktop", enabled);
			}),
	)
	.command(
		"set-always-on",
		new Command()
			.description(
				"Set always-on mode in machine.nix (prevents sleep, enables screensaver lock)",
			)
			.arguments("<value:string>")
			.action(async (_opts, value: string) => {
				const enabled = parseBool(value);
				if (enabled === null) {
					printError("Value must be 'on', 'off', 'true', or 'false'");
					Deno.exit(1);
				}
				await setMachineNixField("alwaysOn", enabled);
			}),
	)
	.command(
		"add-preset",
		new Command()
			.description("Add a machine preset to machine.nix")
			.arguments("<preset:string>")
			.action(async (_opts, preset: string) => {
				const normalized = preset.toLowerCase();
				if (!(normalized in MACHINE_PRESETS)) {
					printError(`Unknown preset: ${preset}`);
					printInfo(
						`Available presets: ${Object.keys(MACHINE_PRESETS).join(", ")}`,
					);
					Deno.exit(1);
				}
				await addMachinePreset(normalized);
			}),
	)
	.command(
		"remove-preset",
		new Command()
			.description("Remove a machine preset from machine.nix")
			.arguments("<preset:string>")
			.action(async (_opts, preset: string) => {
				await removeMachinePreset(preset.toLowerCase());
			}),
	)
	.command(
		"regenerate",
		new Command()
			.description("Regenerate machine.nix (detect system, hostname, etc.)")
			.option("--force", "Overwrite existing machine.nix")
			.action(async (opts) => {
				const dotfilesDir = await resolveDotfilesDir();
				const genScript =
					`${dotfilesDir}/Configs/scripts/.local/bin/generate-machine-config`;
				const args: string[] = [];
				if (opts.force) args.push("--force");

				const { code, success } = await runCommand([genScript, ...args], {
					cwd: dotfilesDir,
				});

				if (!success) {
					printError(`Machine config regeneration failed (exit code ${code})`);
					Deno.exit(code);
				}
			}),
	);

// --- Helper functions ---

function parseBool(value: string): boolean | null {
	switch (value.toLowerCase()) {
		case "on":
		case "true":
		case "1":
		case "yes":
			return true;
		case "off":
		case "false":
		case "0":
		case "no":
			return false;
		default:
			return null;
	}
}

async function setMachineNixField(
	field: string,
	value: boolean,
): Promise<void> {
	const dotfilesDir = await resolveDotfilesDir();
	const nixDir = await resolveNixConfigDir(dotfilesDir);
	const configPath = machineConfigPath(nixDir);

	let content: string;
	try {
		content = await Deno.readTextFile(configPath);
	} catch {
		printError(`machine.nix not found at: ${configPath}`);
		printInfo(
			"Run 'dotfiles setup' or 'dotfiles machine regenerate' to create it.",
		);
		Deno.exit(1);
	}

	const valueStr = value ? "true" : "false";
	const fieldLine = `  ${field} = ${valueStr};`;

	if (content.includes(`${field} =`)) {
		// Replace existing field
		content = content.replace(
			new RegExp(`^\\s*${field}\\s*=\\s*(true|false);\\s*$`, "m"),
			fieldLine,
		);
	} else {
		// Add field before closing brace
		content = content.replace(/\n\}\s*$/, `\n${fieldLine}\n}`);
	}

	await Deno.writeTextFile(configPath, content);
	printSuccess(`Set ${field} = ${valueStr} in machine.nix`);
}

async function addMachinePreset(preset: string): Promise<void> {
	const dotfilesDir = await resolveDotfilesDir();
	const nixDir = await resolveNixConfigDir(dotfilesDir);
	const configPath = machineConfigPath(nixDir);

	let content: string;
	try {
		content = await Deno.readTextFile(configPath);
	} catch {
		printError(`machine.nix not found at: ${configPath}`);
		Deno.exit(1);
	}

	// Parse current presets
	const currentEntries = parsePresetsFromContent(content);
	if (currentEntries.includes(preset)) {
		printInfo(`Preset '${preset}' is already present in machine.nix`);
		return;
	}

	const newEntries = [...currentEntries, preset];
	const presetLine = `  presets = [${
		newEntries.map((p) => `"${p}"`).join(" ")
	}];`;

	if (content.includes("presets =")) {
		content = content.replace(
			new RegExp("^\\s*presets\\s*=\\s*\\[[^\\]]*\\];\\s*$", "m"),
			presetLine,
		);
	} else {
		content = content.replace(
			/\n\}\s*$/,
			"\n  # Machine presets — determines which feature sets to enable\n" +
				presetLine +
				"\n}",
		);
	}

	await Deno.writeTextFile(configPath, content);
	printSuccess(`Added preset '${preset}' to machine.nix`);
	if (MACHINE_PRESETS[preset]) {
		console.log(`  ${MACHINE_PRESETS[preset]}`);
	}
}

async function removeMachinePreset(preset: string): Promise<void> {
	const dotfilesDir = await resolveDotfilesDir();
	const nixDir = await resolveNixConfigDir(dotfilesDir);
	const configPath = machineConfigPath(nixDir);

	let content: string;
	try {
		content = await Deno.readTextFile(configPath);
	} catch {
		printError(`machine.nix not found at: ${configPath}`);
		Deno.exit(1);
	}

	if (!content.includes("presets =")) {
		return; // nothing to remove
	}

	const currentEntries = parsePresetsFromContent(content);
	const newEntries = currentEntries.filter((p) => p !== preset);

	if (newEntries.length === 0) {
		// Remove the presets line entirely (and its comment)
		content = content.replace(
			new RegExp(
				`^[ \t]*#\\s*Machine presets.*\\n?[ \t]*presets\\s*=\\s*\\[\\s*\\];\\s*\\n?`,
				"m",
			),
			"",
		);
	} else {
		const presetLine = `  presets = [${
			newEntries.map((p) => `"${p}"`).join(" ")
		}];`;
		content = content.replace(
			new RegExp("^\\s*presets\\s*=\\s*\\[[^\\]]*\\];\\s*$", "m"),
			presetLine,
		);
	}

	await Deno.writeTextFile(configPath, content);
	printSuccess(`Removed preset '${preset}' from machine.nix`);
}

function parsePresetsFromContent(content: string): string[] {
	const match = content.match(/presets\s*=\s*\[([^\]]*)\]/);
	if (!match) return [];
	return match[1]
		.trim()
		.split(/\s+/)
		.filter((s) => s.length > 0)
		.map((s) => s.replace(/^"|"$/g, ""));
}
