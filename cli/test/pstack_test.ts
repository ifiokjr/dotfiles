import { assertEquals, assertRejects } from "@std/assert";
import { exists } from "@std/fs";
import { join } from "@std/path";
import {
	installPstackSkillsFromCheckout,
	PSTACK_SKILLS,
	verifyPstackSkillDeployment,
} from "../lib/pstack.ts";

const TEST_SHA = "0123456789abcdef0123456789abcdef01234567";

Deno.test("P-Stack sync replaces the managed skill set and records its source", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "pstack-test-" });
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
		for (const skill of PSTACK_SKILLS) {
			const source = join(checkoutDir, "pstack", "skills", skill);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(
				join(source, "SKILL.md"),
				`---\nname: ${skill}\ndescription: test\n---\n`,
			);
		}

		const oldSkill = join(managedRoot, PSTACK_SKILLS[0]);
		await Deno.mkdir(oldSkill, { recursive: true });
		await Deno.writeTextFile(join(oldSkill, "stale.md"), "remove me");

		await installPstackSkillsFromCheckout(
			checkoutDir,
			dotfilesDir,
			TEST_SHA,
		);

		for (const skill of PSTACK_SKILLS) {
			assertEquals(
				await exists(join(managedRoot, skill, "SKILL.md"), { isFile: true }),
				true,
			);
		}
		assertEquals(await exists(join(oldSkill, "stale.md")), false);

		const manifest = JSON.parse(
			await Deno.readTextFile(join(managedRoot, ".pstack-source.json")),
		) as { resolvedSha: string; skills: string[] };
		assertEquals(manifest.resolvedSha, TEST_SHA);
		assertEquals(manifest.skills, [...PSTACK_SKILLS]);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("P-Stack sync rejects an incomplete checkout before changing skills", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "pstack-test-" });
	const checkoutDir = join(tempDir, "checkout");
	const dotfilesDir = join(tempDir, "dotfiles");
	const sentinel = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
		PSTACK_SKILLS[0],
		"sentinel.md",
	);

	try {
		await Deno.mkdir(join(checkoutDir, "pstack", "skills"), {
			recursive: true,
		});
		await Deno.mkdir(join(sentinel, ".."), { recursive: true });
		await Deno.writeTextFile(sentinel, "keep me");

		await assertRejects(
			() =>
				installPstackSkillsFromCheckout(
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

Deno.test("P-Stack deployment verification follows shared directory symlinks", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "pstack-test-" });
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

	try {
		await Deno.mkdir(deployedRoot, { recursive: true });
		for (const skill of PSTACK_SKILLS) {
			const source = join(managedRoot, skill);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(join(source, "SKILL.md"), skill);
			await Deno.symlink(source, join(deployedRoot, skill), {
				type: "dir",
			});
		}

		assertEquals(
			await verifyPstackSkillDeployment(dotfilesDir, homeDir),
			[],
		);

		await Deno.remove(join(deployedRoot, PSTACK_SKILLS[0]));
		assertEquals(
			await verifyPstackSkillDeployment(dotfilesDir, homeDir),
			[`${PSTACK_SKILLS[0]}/SKILL.md: missing`],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
