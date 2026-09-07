import { assert, assertEquals } from "@std/assert";
import { exists } from "@std/fs";
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
	refreshShellIntegrations,
	resolveDeployedDotfilesDir,
	resolveDotfilesDir,
	resolveMachineConfigPath,
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

Deno.test("resolveMachineConfigPath follows the flake lookup order", async () => {
	const previousHome = Deno.env.get("HOME");
	const homeDir = await Deno.makeTempDir();
	const dotfilesDir = await Deno.makeTempDir();
	const nixConfigDir = join(dotfilesDir, "Configs/nix/.config/nix");

	try {
		Deno.env.set("HOME", homeDir);

		// With no machine.nix anywhere, the canonical ~/.config/nix location is
		// returned as the generation target.
		assertEquals(
			await resolveMachineConfigPath(nixConfigDir),
			join(homeDir, ".config/nix/machine.nix"),
		);

		// A repo-side copy wins, matching the flake's NIX_USER_CONFIG_DIR lookup.
		await Deno.mkdir(nixConfigDir, { recursive: true });
		const repoMachinePath = join(nixConfigDir, "machine.nix");
		await Deno.writeTextFile(repoMachinePath, "{}");
		assertEquals(
			await resolveMachineConfigPath(nixConfigDir),
			repoMachinePath,
		);

		// Without the repo copy, the canonical ~/.config/nix file is used.
		await Deno.remove(repoMachinePath);
		const linkMachinePath = join(homeDir, ".config/nix/machine.nix");
		await Deno.mkdir(join(homeDir, ".config/nix"), { recursive: true });
		await Deno.writeTextFile(linkMachinePath, "{}");
		assertEquals(
			await resolveMachineConfigPath(nixConfigDir),
			linkMachinePath,
		);
	} finally {
		if (previousHome === undefined) {
			Deno.env.delete("HOME");
		} else {
			Deno.env.set("HOME", previousHome);
		}

		await Deno.remove(homeDir, { recursive: true });
		await Deno.remove(dotfilesDir, { recursive: true });
	}
});

Deno.test("resolveDeployedDotfilesDir derives the root from nix symlinks", async () => {
	const previousHome = Deno.env.get("HOME");
	const homeDir = await Deno.makeTempDir();
	const fakeRepo = await Deno.makeTempDir();
	const nixDir = join(fakeRepo, "Configs/nix/.config/nix");

	try {
		Deno.env.set("HOME", homeDir);

		// No ~/.config/nix at all.
		assertEquals(await resolveDeployedDotfilesDir(), null);

		// A real ~/.config/nix without a flake.nix symlink is also ignored.
		await Deno.mkdir(join(homeDir, ".config/nix"), { recursive: true });
		assertEquals(await resolveDeployedDotfilesDir(), null);

		await Deno.mkdir(nixDir, { recursive: true });
		await Deno.writeTextFile(join(nixDir, "flake.nix"), "{}");
		await Deno.writeTextFile(join(fakeRepo, "setup"), "#!/usr/bin/env bash\n");

		// Dir-level symlink: ~/.config/nix -> the repo's nix config dir.
		await Deno.remove(join(homeDir, ".config/nix"));
		await Deno.symlink(nixDir, join(homeDir, ".config/nix"));
		assertEquals(
			await resolveDeployedDotfilesDir(),
			await Deno.realPath(fakeRepo),
		);

		// File-level symlink farm: real ~/.config/nix with flake.nix linked in.
		await Deno.remove(join(homeDir, ".config/nix"));
		await Deno.mkdir(join(homeDir, ".config/nix"));
		await Deno.symlink(
			join(nixDir, "flake.nix"),
			join(homeDir, ".config/nix/flake.nix"),
		);
		assertEquals(
			await resolveDeployedDotfilesDir(),
			await Deno.realPath(fakeRepo),
		);

		// Symlinks that don't point inside a dotfiles checkout are ignored.
		const unrelatedDir = await Deno.makeTempDir();
		await Deno.remove(join(homeDir, ".config/nix/flake.nix"));
		await Deno.remove(join(homeDir, ".config/nix"));
		await Deno.symlink(unrelatedDir, join(homeDir, ".config/nix"));
		assertEquals(await resolveDeployedDotfilesDir(), null);
		await Deno.remove(unrelatedDir, { recursive: true });
	} finally {
		if (previousHome === undefined) {
			Deno.env.delete("HOME");
		} else {
			Deno.env.set("HOME", previousHome);
		}

		await Deno.remove(homeDir, { recursive: true });
		await Deno.remove(fakeRepo, { recursive: true });
	}
});

Deno.test("refreshShellIntegrations tolerates missing and failing scripts", async () => {
	const tempDir = await Deno.makeTempDir();
	const marker = join(tempDir, "marker.txt");

	try {
		// Missing script: skipped without error.
		assertEquals(await refreshShellIntegrations(tempDir), false);

		// Successful script: runs and reports success.
		const binDir = join(tempDir, "Configs/scripts/.local/bin");
		await Deno.mkdir(binDir, { recursive: true });
		const script = join(binDir, "refresh-nu-vendor-autoloads");
		await Deno.writeTextFile(
			script,
			`#!/usr/bin/env bash\ntouch "${marker}"\n`,
		);
		await Deno.chmod(script, 0o755);
		assertEquals(await refreshShellIntegrations(tempDir), true);
		assert(await exists(marker));

		// Failing script: reported as skipped, but never fatal.
		await Deno.writeTextFile(script, "#!/usr/bin/env bash\nexit 3\n");
		assertEquals(await refreshShellIntegrations(tempDir), false);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
