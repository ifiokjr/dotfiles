import { assert, assertEquals } from "@std/assert";
import { join } from "@std/path";
import {
	commandExists,
	detectArch,
	detectPlatform,
	discoverGroups,
	findExecutable,
	formatCommand,
	loadGroupMetadata,
	machineConfigPath,
	nixSystem,
	resolveDotfilesDir,
	resolveNixConfigDir,
	runCommand,
} from "../lib/config.ts";

Deno.test("platform helpers return supported labels", () => {
	const platform = detectPlatform();
	const system = nixSystem();

	assert(["macos", "linux", "windows", "bsd"].includes(platform));
	assert(system.startsWith(`${detectArch()}-`));
});

Deno.test("resolveDotfilesDir honors DOTFILES_DIR", async () => {
	const previous = Deno.env.get("DOTFILES_DIR");
	const tempDir = await Deno.makeTempDir();

	try {
		Deno.env.set("DOTFILES_DIR", tempDir);
		assertEquals(await resolveDotfilesDir(), tempDir);
	} finally {
		if (previous === undefined) {
			Deno.env.delete("DOTFILES_DIR");
		} else {
			Deno.env.set("DOTFILES_DIR", previous);
		}

		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("resolveDotfilesDir walks up from cwd", async () => {
	const previousEnv = Deno.env.get("DOTFILES_DIR");
	const previousCwd = Deno.cwd();
	const tempDir = await Deno.makeTempDir();
	const nestedDir = join(tempDir, "a/b/c");

	try {
		Deno.env.delete("DOTFILES_DIR");
		await Deno.mkdir(join(tempDir, "Configs"));
		await Deno.writeTextFile(join(tempDir, "setup"), "#!/usr/bin/env bash\n");
		await Deno.mkdir(nestedDir, { recursive: true });
		Deno.chdir(nestedDir);

		assertEquals(
			await Deno.realPath(await resolveDotfilesDir()),
			await Deno.realPath(tempDir),
		);
	} finally {
		Deno.chdir(previousCwd);

		if (previousEnv === undefined) {
			Deno.env.delete("DOTFILES_DIR");
		} else {
			Deno.env.set("DOTFILES_DIR", previousEnv);
		}

		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("discoverGroups finds repository config groups", async () => {
	const dotfilesDir = await resolveDotfilesDir();
	const groups = await discoverGroups(dotfilesDir);

	assert(groups.length > 0);
	assert(groups.includes("nix"));
	assertEquals(groups, groups.toSorted());
});

Deno.test("discoverGroups returns empty when Configs is missing", async () => {
	const tempDir = await Deno.makeTempDir();

	try {
		assertEquals(await discoverGroups(tempDir), []);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("loadGroupMetadata parses metadata and applies defaults", async () => {
	const tempDir = await Deno.makeTempDir();

	try {
		await Deno.mkdir(join(tempDir, "Configs"));
		await Deno.writeTextFile(
			join(tempDir, "Configs/example.group.toml"),
			`description = "Example group"
presets = ["core", "dev"]
depends_on = shell editor
phase = "late"
platforms = ["macos", "linux"]
ignored line
`,
		);

		assertEquals(await loadGroupMetadata(tempDir, "example"), {
			description: "Example group",
			dependsOn: ["shell", "editor"],
			phase: "late",
			platforms: ["macos", "linux"],
			presets: ["core", "dev"],
		});

		assertEquals(await loadGroupMetadata(tempDir, "missing"), {
			description: "missing",
			dependsOn: [],
			phase: "normal",
			platforms: [],
			presets: [],
		});
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("nix config and machine paths resolve", async () => {
	const previousHome = Deno.env.get("HOME");
	const homeDir = await Deno.makeTempDir();
	const dotfilesDir = await Deno.makeTempDir();
	const targetDir = await Deno.makeTempDir();

	try {
		Deno.env.set("HOME", homeDir);
		let nixConfigDir = await resolveNixConfigDir(dotfilesDir);

		assertEquals(nixConfigDir, join(dotfilesDir, "Configs/nix/.config/nix"));
		assertEquals(
			machineConfigPath(nixConfigDir),
			join(nixConfigDir, "machine.nix"),
		);

		await Deno.mkdir(join(homeDir, ".config"));
		await Deno.symlink(targetDir, join(homeDir, ".config/nix"));
		nixConfigDir = await resolveNixConfigDir(dotfilesDir);

		assertEquals(nixConfigDir, await Deno.realPath(targetDir));
	} finally {
		if (previousHome === undefined) {
			Deno.env.delete("HOME");
		} else {
			Deno.env.set("HOME", previousHome);
		}

		await Deno.remove(homeDir, { recursive: true });
		await Deno.remove(dotfilesDir, { recursive: true });
		await Deno.remove(targetDir, { recursive: true });
	}
});

Deno.test("command helpers handle success and failure", async () => {
	assert(await commandExists(Deno.execPath()));
	assert(!await commandExists("definitely-not-a-dotfiles-command"));
	assert(await findExecutable("deno"));
	assertEquals(await findExecutable("definitely-not-a-dotfiles-command"), null);

	const result = await runCommand([
		Deno.execPath(),
		"eval",
		"console.log(Deno.env.get('DOTFILES_TEST_VALUE'))",
	], {
		env: { DOTFILES_TEST_VALUE: "hello" },
		stdout: "piped",
	});

	assertEquals(result, { code: 0, stdout: "hello\n", success: true });
	assertEquals(
		formatCommand(["dot", "groups", "info", "two words"]),
		'dot groups info "two words"',
	);
});
