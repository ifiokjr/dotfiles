import { assertEquals } from "@std/assert";
import { exists } from "@std/fs";
import { join } from "@std/path";
import {
	type ManagedSkillSource,
	repairAgentSkillDeployment,
	verifyManagedSkillDeployment,
} from "../lib/managed_skills.ts";

const DEMO_SOURCE: ManagedSkillSource = {
	displayName: "Demo",
	manifestFile: ".demo-source.json",
	repository: "example/demo",
	ref: "main",
	skills: [{ name: "greet", sourcePath: "skills/greet" }],
	tempPrefix: "demo-test-",
	transactionLabel: "demo",
	userAgent: "dotfiles-cli-test",
};

/** Repo side with one managed skill shipping SKILL.md and refs/note.md. */
async function writeManagedSkill(dotfilesDir: string): Promise<string> {
	const managedSkill = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
		"greet",
	);
	await Deno.mkdir(join(managedSkill, "refs"), { recursive: true });
	await Deno.writeTextFile(join(managedSkill, "SKILL.md"), "greet");
	await Deno.writeTextFile(join(managedSkill, "refs", "note.md"), "note");

	return managedSkill;
}

Deno.test("repair prunes dangling checkout links so the deploy can relink", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "repair-test-" });
	const dotfilesDir = join(tempDir, "dotfiles");
	const homeDir = join(tempDir, "home");

	try {
		const managedSkill = await writeManagedSkill(dotfilesDir);

		// The deployed shape after a skill moved inside the repo: per-file links
		// into the checkout where the old target paths no longer exist.
		const deployedSkill = join(homeDir, ".agents", "skills", "greet");
		await Deno.mkdir(join(deployedSkill, "refs"), { recursive: true });

		const staleShallow = join(deployedSkill, "old.md");
		const staleDeep = join(deployedSkill, "refs", "note.md");
		await Deno.symlink(join(managedSkill, "gone.md"), staleShallow);
		await Deno.symlink(join(managedSkill, "gone-deep.md"), staleDeep);

		// A working link the next deploy must not disturb.
		const fresh = join(deployedSkill, "SKILL.md");
		await Deno.symlink(join(managedSkill, "SKILL.md"), fresh);

		// A link pointing somewhere else and a real file stay no matter how
		// broken they are; they are not this repo's residue.
		const foreign = join(deployedSkill, "foreign.md");
		await Deno.symlink(join(tempDir, "elsewhere", "gone.md"), foreign);
		const realFile = join(deployedSkill, "README.md");
		await Deno.writeTextFile(realFile, "real");

		const pruned = await repairAgentSkillDeployment(homeDir);

		assertEquals(pruned.toSorted(), [staleShallow, staleDeep].toSorted());
		assertEquals(await exists(staleShallow), false);
		assertEquals(await exists(staleDeep), false);
		assertEquals(await exists(fresh), true);
		assertEquals(await exists(realFile), true);
		assertEquals((await Deno.lstat(foreign)).isSymlink, true);

		// With the drift gone, relinking (tuckr's job, simulated here) verifies
		// clean instead of reporting the old paths as missing forever.
		await Deno.symlink(join(managedSkill, "refs", "note.md"), staleDeep);
		assertEquals(
			await verifyManagedSkillDeployment(DEMO_SOURCE, dotfilesDir, homeDir),
			[],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("repair also prunes the .pi compatibility root and skips missing roots", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "repair-test-" });
	const dotfilesDir = join(tempDir, "dotfiles");
	const homeDir = join(tempDir, "home");

	try {
		const managedSkill = await writeManagedSkill(dotfilesDir);

		// The .pi compatibility root holds per-file links of its own; a retired
		// source file leaves one dangling there too.
		const piSkill = join(homeDir, ".pi", "agent", "skills", "greet");
		await Deno.mkdir(piSkill, { recursive: true });
		const stalePi = join(piSkill, "retired.md");
		await Deno.symlink(join(managedSkill, "retired.md"), stalePi);

		const pruned = await repairAgentSkillDeployment(homeDir);

		assertEquals(pruned, [stalePi]);
		assertEquals(await exists(stalePi), false);

		// A home without the deployed roots at all is not an error; a fresh
		// machine simply has nothing to prune.
		assertEquals(await repairAgentSkillDeployment(join(tempDir, "empty")), []);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
