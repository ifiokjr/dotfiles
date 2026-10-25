import { assertEquals, assertRejects } from "@std/assert";
import { exists } from "@std/fs";
import { join } from "@std/path";
import {
	installSlopperSkillsFromCheckout,
	SLOPPER_SKILLS,
	SLOPPER_SOURCE,
	verifySlopperSkillDeployment,
} from "../lib/slopper.ts";

const TEST_SHA = "0123456789abcdef0123456789abcdef01234567";

Deno.test("Slopper sync replaces the managed skill set and records its source", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "slopper-test-" });
	const checkoutDir = join(tempDir, "checkout");
	const dotfilesDir = join(tempDir, "dotfiles");
	const managedRoot = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);

	try {
		for (const skill of SLOPPER_SOURCE.skills) {
			const source = join(checkoutDir, skill.sourcePath);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(
				join(source, "SKILL.md"),
				`---\nname: ${skill.name}\ndescription: test\n---\n`,
			);
		}

		const oldSkill = join(managedRoot, SLOPPER_SKILLS[0]);
		await Deno.mkdir(oldSkill, { recursive: true });
		await Deno.writeTextFile(join(oldSkill, "stale.md"), "remove me");

		await installSlopperSkillsFromCheckout(checkoutDir, dotfilesDir, TEST_SHA);

		for (const skill of SLOPPER_SKILLS) {
			assertEquals(
				await exists(join(managedRoot, skill, "SKILL.md"), { isFile: true }),
				true,
			);
		}
		assertEquals(await exists(join(oldSkill, "stale.md")), false);

		const manifest = JSON.parse(
			await Deno.readTextFile(join(managedRoot, ".slopper-source.json")),
		) as { resolvedSha: string; skills: string[] };
		assertEquals(manifest.resolvedSha, TEST_SHA);
		assertEquals(manifest.skills, [...SLOPPER_SKILLS]);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("Slopper sync rejects an incomplete checkout before changing skills", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "slopper-test-" });
	const checkoutDir = join(tempDir, "checkout");
	const dotfilesDir = join(tempDir, "dotfiles");
	const sentinel = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
		SLOPPER_SKILLS[0],
		"sentinel.md",
	);

	try {
		await Deno.mkdir(checkoutDir, { recursive: true });
		await Deno.mkdir(join(sentinel, ".."), { recursive: true });
		await Deno.writeTextFile(sentinel, "keep me");

		await assertRejects(
			() =>
				installSlopperSkillsFromCheckout(checkoutDir, dotfilesDir, TEST_SHA),
			Error,
			"missing SKILL.md",
		);
		assertEquals(await Deno.readTextFile(sentinel), "keep me");
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("Slopper deployment verification checks shared and Pi paths", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "slopper-test-" });
	const dotfilesDir = join(tempDir, "dotfiles");
	const homeDir = join(tempDir, "home");
	const managedRoot = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);
	const deployedRoot = join(homeDir, ".agents", "skills");
	const piRoot = join(homeDir, ".pi", "agent", "skills");

	try {
		await Deno.mkdir(deployedRoot, { recursive: true });
		await Deno.mkdir(piRoot, { recursive: true });

		for (const skill of SLOPPER_SKILLS) {
			const source = join(managedRoot, skill);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(join(source, "SKILL.md"), skill);

			for (const root of [deployedRoot, piRoot]) {
				await Deno.symlink(source, join(root, skill), { type: "dir" });
			}
		}

		assertEquals(await verifySlopperSkillDeployment(dotfilesDir, homeDir), []);

		await Deno.remove(join(piRoot, SLOPPER_SKILLS[0]));
		assertEquals(
			await verifySlopperSkillDeployment(dotfilesDir, homeDir),
			[`.pi/agent/skills: ${SLOPPER_SKILLS[0]}/SKILL.md: missing`],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
