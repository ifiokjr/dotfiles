import { assertEquals, assertRejects } from "@std/assert";
import { exists } from "@std/fs";
import { join } from "@std/path";
import {
	installPinaSkillsFromCheckout,
	PINA_SKILLS,
	PINA_SOURCE,
	verifyPinaSkillDeployment,
} from "../lib/pina.ts";

const TEST_SHA = "0123456789abcdef0123456789abcdef01234567";

Deno.test("pina sync replaces the managed skill set and records its source", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "pina-test-" });
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
		for (const skill of PINA_SOURCE.skills) {
			const source = join(checkoutDir, skill.sourcePath);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(
				join(source, "SKILL.md"),
				`---\nname: ${skill.name}\ndescription: test\n---\n`,
			);
		}

		const oldSkill = join(managedRoot, PINA_SKILLS[0]);
		await Deno.mkdir(oldSkill, { recursive: true });
		await Deno.writeTextFile(join(oldSkill, "stale.md"), "remove me");

		await installPinaSkillsFromCheckout(checkoutDir, dotfilesDir, TEST_SHA);

		for (const skill of PINA_SKILLS) {
			assertEquals(
				await exists(join(managedRoot, skill, "SKILL.md"), { isFile: true }),
				true,
			);
		}
		assertEquals(await exists(join(oldSkill, "stale.md")), false);

		const manifest = JSON.parse(
			await Deno.readTextFile(join(managedRoot, ".pina-source.json")),
		) as { resolvedSha: string; skills: string[] };
		assertEquals(manifest.resolvedSha, TEST_SHA);
		assertEquals(manifest.skills, [...PINA_SKILLS]);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("pina sync rejects an incomplete checkout before changing skills", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "pina-test-" });
	const checkoutDir = join(tempDir, "checkout");
	const dotfilesDir = join(tempDir, "dotfiles");
	const sentinel = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
		PINA_SKILLS[0],
		"sentinel.md",
	);

	try {
		await Deno.mkdir(checkoutDir, { recursive: true });
		await Deno.mkdir(join(sentinel, ".."), { recursive: true });
		await Deno.writeTextFile(sentinel, "keep me");

		await assertRejects(
			() => installPinaSkillsFromCheckout(checkoutDir, dotfilesDir, TEST_SHA),
			Error,
			"missing SKILL.md",
		);
		assertEquals(await Deno.readTextFile(sentinel), "keep me");
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("pina deployment verification checks shared and Pi paths", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "pina-test-" });
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

		for (const skill of PINA_SKILLS) {
			const source = join(managedRoot, skill);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(join(source, "SKILL.md"), skill);

			for (const root of [deployedRoot, piRoot]) {
				await Deno.symlink(source, join(root, skill), { type: "dir" });
			}
		}

		assertEquals(await verifyPinaSkillDeployment(dotfilesDir, homeDir), []);

		await Deno.remove(join(piRoot, PINA_SKILLS[0]));
		assertEquals(
			await verifyPinaSkillDeployment(dotfilesDir, homeDir),
			[`.pi/agent/skills: ${PINA_SKILLS[0]}/SKILL.md: missing`],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
