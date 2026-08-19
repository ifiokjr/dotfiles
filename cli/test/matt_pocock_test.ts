import { assertEquals, assertRejects } from "@std/assert";
import { exists } from "@std/fs";
import { join } from "@std/path";
import {
	installMattPocockSkillsFromCheckout,
	MATT_POCOCK_SKILLS,
	MATT_POCOCK_SOURCE,
	verifyMattPocockSkillDeployment,
} from "../lib/matt_pocock.ts";

const TEST_SHA = "0123456789abcdef0123456789abcdef01234567";

Deno.test("Matt Pocock sync replaces the managed skill set and records its source", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "matt-pocock-test-" });
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
		for (const skill of MATT_POCOCK_SOURCE.skills) {
			const source = join(checkoutDir, skill.sourcePath);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(
				join(source, "SKILL.md"),
				`---\nname: ${skill.name}\ndescription: test\n---\n`,
			);
		}

		const oldSkill = join(managedRoot, MATT_POCOCK_SKILLS[0]);
		await Deno.mkdir(oldSkill, { recursive: true });
		await Deno.writeTextFile(join(oldSkill, "stale.md"), "remove me");

		await installMattPocockSkillsFromCheckout(
			checkoutDir,
			dotfilesDir,
			TEST_SHA,
		);

		for (const skill of MATT_POCOCK_SKILLS) {
			assertEquals(
				await exists(join(managedRoot, skill, "SKILL.md"), { isFile: true }),
				true,
			);
		}
		assertEquals(await exists(join(oldSkill, "stale.md")), false);

		const manifest = JSON.parse(
			await Deno.readTextFile(
				join(managedRoot, ".matt-pocock-source.json"),
			),
		) as { resolvedSha: string; skills: string[] };
		assertEquals(manifest.resolvedSha, TEST_SHA);
		assertEquals(manifest.skills, [...MATT_POCOCK_SKILLS]);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("Matt Pocock sync rejects an incomplete checkout before changing skills", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "matt-pocock-test-" });
	const checkoutDir = join(tempDir, "checkout");
	const dotfilesDir = join(tempDir, "dotfiles");
	const sentinel = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
		MATT_POCOCK_SKILLS[0],
		"sentinel.md",
	);

	try {
		await Deno.mkdir(checkoutDir, { recursive: true });
		await Deno.mkdir(join(sentinel, ".."), { recursive: true });
		await Deno.writeTextFile(sentinel, "keep me");

		await assertRejects(
			() =>
				installMattPocockSkillsFromCheckout(
					checkoutDir,
					dotfilesDir,
					TEST_SHA,
				),
			Error,
			"missing SKILL.md",
		);
		assertEquals(await Deno.readTextFile(sentinel), "keep me");
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("Matt Pocock deployment verification follows shared directory symlinks", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "matt-pocock-test-" });
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
		for (const skill of MATT_POCOCK_SKILLS) {
			const source = join(managedRoot, skill);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(join(source, "SKILL.md"), skill);
			for (const root of [deployedRoot, piRoot]) {
				await Deno.symlink(source, join(root, skill), {
					type: "dir",
				});
			}
		}

		assertEquals(
			await verifyMattPocockSkillDeployment(dotfilesDir, homeDir),
			[],
		);

		await Deno.remove(join(deployedRoot, MATT_POCOCK_SKILLS[0]));
		assertEquals(
			await verifyMattPocockSkillDeployment(dotfilesDir, homeDir),
			[`${MATT_POCOCK_SKILLS[0]}/SKILL.md: missing`],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
