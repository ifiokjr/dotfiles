import { assertEquals, assertRejects } from "@std/assert";
import { exists } from "@std/fs";
import { join } from "@std/path";
import {
	installSecurityAuditSkillsFromCheckout,
	SECURITY_AUDIT_SKILLS,
	SECURITY_AUDIT_SOURCE,
	verifySecurityAuditSkillDeployment,
} from "../lib/security_audit.ts";

const TEST_SHA = "0123456789abcdef0123456789abcdef01234567";

Deno.test("security-audit sync replaces the managed skill set and records its source", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "security-audit-test-" });
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
		for (const skill of SECURITY_AUDIT_SOURCE.skills) {
			const source = join(checkoutDir, skill.sourcePath);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(
				join(source, "SKILL.md"),
				`---\nname: ${skill.name}\ndescription: test\n---\n`,
			);
		}

		const oldSkill = join(managedRoot, SECURITY_AUDIT_SKILLS[0]);
		await Deno.mkdir(oldSkill, { recursive: true });
		await Deno.writeTextFile(join(oldSkill, "stale.md"), "remove me");

		await installSecurityAuditSkillsFromCheckout(
			checkoutDir,
			dotfilesDir,
			TEST_SHA,
		);

		for (const skill of SECURITY_AUDIT_SKILLS) {
			assertEquals(
				await exists(join(managedRoot, skill, "SKILL.md"), { isFile: true }),
				true,
			);
		}
		assertEquals(await exists(join(oldSkill, "stale.md")), false);

		const manifest = JSON.parse(
			await Deno.readTextFile(
				join(managedRoot, ".security-audit-source.json"),
			),
		) as { ref: string; resolvedSha: string; skills: string[] };
		assertEquals(manifest.ref, "main");
		assertEquals(manifest.resolvedSha, TEST_SHA);
		assertEquals(manifest.skills, [...SECURITY_AUDIT_SKILLS]);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("security-audit sync rejects an incomplete checkout before changing skills", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "security-audit-test-" });
	const checkoutDir = join(tempDir, "checkout");
	const dotfilesDir = join(tempDir, "dotfiles");
	const sentinel = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
		SECURITY_AUDIT_SKILLS[0],
		"sentinel.md",
	);

	try {
		await Deno.mkdir(checkoutDir, { recursive: true });
		await Deno.mkdir(join(sentinel, ".."), { recursive: true });
		await Deno.writeTextFile(sentinel, "keep me");

		await assertRejects(
			() =>
				installSecurityAuditSkillsFromCheckout(
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

Deno.test("security-audit deployment verification checks shared and Pi paths", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "security-audit-test-" });
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

		for (const skill of SECURITY_AUDIT_SKILLS) {
			const source = join(managedRoot, skill);
			await Deno.mkdir(source, { recursive: true });
			await Deno.writeTextFile(join(source, "SKILL.md"), skill);

			for (const root of [deployedRoot, piRoot]) {
				await Deno.symlink(source, join(root, skill), { type: "dir" });
			}
		}

		assertEquals(
			await verifySecurityAuditSkillDeployment(dotfilesDir, homeDir),
			[],
		);

		await Deno.remove(join(piRoot, SECURITY_AUDIT_SKILLS[0]));
		assertEquals(
			await verifySecurityAuditSkillDeployment(dotfilesDir, homeDir),
			[
				`.pi/agent/skills: ${SECURITY_AUDIT_SKILLS[0]}/SKILL.md: missing`,
			],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
