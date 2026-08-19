import { copy, exists, walk } from "@std/fs";
import { isAbsolute, join, relative, resolve } from "@std/path";

const PSTACK_REPOSITORY = "cursor/plugins";
const PSTACK_REF = "main";

export const PSTACK_SKILLS = [
	"principle-prove-it-works",
	"principle-type-system-discipline",
	"principle-fix-root-causes",
	"blast-radius",
	"how",
	"principle-laziness-protocol",
	"recall",
	"principle-boundary-discipline",
	"technical-writing",
	"unslop",
	"architect",
	"principle-model-the-domain",
	"principle-minimize-reader-load",
	"principle-sequence-verifiable-units",
	"principle-subtract-before-you-add",
	"interrogate",
	"why",
	"create-verification-skill",
	"show-me-your-work",
	"principle-make-operations-idempotent",
] as const;

interface PstackManifest {
	repository: string;
	ref: string;
	resolvedSha: string;
	skills: readonly string[];
	version: 1;
}

interface StagedSkill {
	backup: string;
	hadOriginal: boolean;
	replacementPlaced: boolean;
	stage: string;
	target: string;
}

export interface PstackSyncResult {
	resolvedSha: string;
	skillCount: number;
}

/** Confirm every managed source file resolves through the shared skill path. */
export async function verifyPstackSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	const managedRoot = resolve(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);
	const deployedRoot = resolve(homeDir, ".agents", "skills");
	const issues: string[] = [];

	for (const skill of PSTACK_SKILLS) {
		const sourceRoot = resolve(managedRoot, skill);
		const deployedSkillRoot = resolve(deployedRoot, skill);

		for await (
			const entry of walk(sourceRoot, {
				includeDirs: false,
				includeSymlinks: false,
			})
		) {
			const pathWithinSkill = relative(sourceRoot, entry.path);
			const deployedPath = resolve(deployedSkillRoot, pathWithinSkill);
			if (!(await exists(deployedPath))) {
				issues.push(`${skill}/${pathWithinSkill}: missing`);
				continue;
			}

			const [sourceRealPath, deployedRealPath] = await Promise.all([
				Deno.realPath(entry.path),
				Deno.realPath(deployedPath),
			]);
			if (sourceRealPath !== deployedRealPath) {
				issues.push(`${skill}/${pathWithinSkill}: not dotfiles-managed`);
			}
		}
	}

	return issues;
}

/** Fetch the latest selected P-Stack skills and install them into the repo. */
export async function syncPstackSkills(
	dotfilesDir: string,
): Promise<PstackSyncResult> {
	const resolvedSha = await resolvePstackSha();
	const tempDir = await Deno.makeTempDir({ prefix: "dot-pstack-" });
	const archivePath = join(tempDir, "plugins.tar.gz");
	const checkoutDir = join(tempDir, "checkout");

	try {
		await Deno.mkdir(checkoutDir, { recursive: true });
		await downloadArchive(resolvedSha, archivePath);
		await extractArchive(archivePath, checkoutDir);
		await installPstackSkillsFromCheckout(
			checkoutDir,
			dotfilesDir,
			resolvedSha,
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true }).catch(() => undefined);
	}

	return { resolvedSha, skillCount: PSTACK_SKILLS.length };
}

/**
 * Replace only the managed P-Stack directories from an extracted checkout.
 *
 * All replacements are staged before the first managed directory changes.
 * Existing directories move to transaction-specific backups and are restored
 * if any later replacement fails.
 */
export async function installPstackSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	assertCommitSha(resolvedSha);

	const managedRoot = resolve(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);
	await Deno.mkdir(managedRoot, { recursive: true });

	const transactionId = crypto.randomUUID();
	const staged: StagedSkill[] = [];

	try {
		for (const skill of PSTACK_SKILLS) {
			const source = resolve(checkoutDir, "pstack", "skills", skill);
			const skillFile = join(source, "SKILL.md");
			if (!(await exists(skillFile, { isFile: true }))) {
				throw new Error(`P-Stack skill is missing SKILL.md: ${skill}`);
			}

			const target = resolve(managedRoot, skill);
			const stage = resolve(
				managedRoot,
				`.${skill}.pstack-next-${transactionId}`,
			);
			const backup = resolve(
				managedRoot,
				`.${skill}.pstack-backup-${transactionId}`,
			);
			assertManagedPath(managedRoot, target);
			assertManagedPath(managedRoot, stage);
			assertManagedPath(managedRoot, backup);

			await copy(source, stage, { overwrite: false });
			staged.push({
				backup,
				hadOriginal: false,
				replacementPlaced: false,
				stage,
				target,
			});
		}

		for (const item of staged) {
			item.hadOriginal = await exists(item.target);
			if (item.hadOriginal) {
				await Deno.rename(item.target, item.backup);
			}

			await Deno.rename(item.stage, item.target);
			item.replacementPlaced = true;
		}

		await writeManifest(managedRoot, transactionId, resolvedSha);

		for (const item of staged) {
			if (item.hadOriginal) {
				await removeManagedPath(managedRoot, item.backup);
			}
		}
	} catch (error) {
		for (const item of [...staged].reverse()) {
			if (item.replacementPlaced) {
				await removeManagedPath(managedRoot, item.target).catch(() =>
					undefined
				);
			}

			if (item.hadOriginal && await exists(item.backup)) {
				await Deno.rename(item.backup, item.target).catch(() => undefined);
			}

			await removeManagedPath(managedRoot, item.stage).catch(() => undefined);
		}

		throw error;
	}
}

async function resolvePstackSha(): Promise<string> {
	const response = await fetch(
		`https://api.github.com/repos/${PSTACK_REPOSITORY}/commits/${PSTACK_REF}`,
		{
			headers: {
				Accept: "application/vnd.github+json",
				"User-Agent": "ifiokjr-dotfiles-pstack-sync",
			},
		},
	);
	if (!response.ok) {
		throw new Error(
			`Failed to resolve P-Stack ${PSTACK_REF}: HTTP ${response.status}`,
		);
	}

	const payload: unknown = await response.json();
	if (!isObject(payload) || typeof payload.sha !== "string") {
		throw new Error("GitHub returned an invalid P-Stack commit response");
	}

	assertCommitSha(payload.sha);
	return payload.sha;
}

async function downloadArchive(resolvedSha: string, archivePath: string) {
	const response = await fetch(
		`https://codeload.github.com/${PSTACK_REPOSITORY}/tar.gz/${resolvedSha}`,
		{ headers: { "User-Agent": "ifiokjr-dotfiles-pstack-sync" } },
	);
	if (!response.ok) {
		throw new Error(`Failed to download P-Stack: HTTP ${response.status}`);
	}

	await Deno.writeFile(
		archivePath,
		new Uint8Array(await response.arrayBuffer()),
	);
}

async function extractArchive(archivePath: string, checkoutDir: string) {
	const command = new Deno.Command("tar", {
		args: [
			"-xzf",
			archivePath,
			"--strip-components=1",
			"-C",
			checkoutDir,
		],
		stderr: "piped",
		stdout: "null",
	});
	const output = await command.output();
	if (!output.success) {
		const stderr = new TextDecoder().decode(output.stderr).trim();
		throw new Error(`Failed to extract P-Stack archive: ${stderr}`);
	}
}

async function writeManifest(
	managedRoot: string,
	transactionId: string,
	resolvedSha: string,
) {
	const manifest: PstackManifest = {
		repository: `https://github.com/${PSTACK_REPOSITORY}`,
		ref: PSTACK_REF,
		resolvedSha,
		skills: PSTACK_SKILLS,
		version: 1,
	};
	const target = resolve(managedRoot, ".pstack-source.json");
	const stage = resolve(
		managedRoot,
		`.pstack-source.next-${transactionId}.json`,
	);
	assertManagedPath(managedRoot, target);
	assertManagedPath(managedRoot, stage);

	await Deno.writeTextFile(stage, `${JSON.stringify(manifest, null, "\t")}\n`);
	await Deno.rename(stage, target);
}

async function removeManagedPath(managedRoot: string, target: string) {
	assertManagedPath(managedRoot, target);
	if (await exists(target)) {
		await Deno.remove(target, { recursive: true });
	}
}

function assertManagedPath(managedRoot: string, target: string) {
	const pathFromRoot = relative(managedRoot, target);
	if (
		!pathFromRoot || pathFromRoot === "." || isAbsolute(pathFromRoot) ||
		pathFromRoot === ".." || pathFromRoot.startsWith(`..${separator()}`)
	) {
		throw new Error(`Refusing path outside the managed skill root: ${target}`);
	}
}

function separator(): string {
	return Deno.build.os === "windows" ? "\\" : "/";
}

function assertCommitSha(value: string) {
	if (!/^[0-9a-f]{40}$/.test(value)) {
		throw new Error(`Invalid P-Stack commit SHA: ${value}`);
	}
}

function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}
