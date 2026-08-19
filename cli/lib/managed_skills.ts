import { copy, exists, walk } from "@std/fs";
import { isAbsolute, join, relative, resolve } from "@std/path";

export interface ManagedSkillSpec {
	name: string;
	sourcePath: string;
}

export interface ManagedSkillSource {
	compatibilityRoots?: readonly string[];
	displayName: string;
	manifestFile: string;
	repository: string;
	ref: string;
	skills: readonly ManagedSkillSpec[];
	tempPrefix: string;
	transactionLabel: string;
	userAgent: string;
}

interface ManagedSkillManifest {
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

export interface ManagedSkillSyncResult {
	resolvedSha: string;
	skillCount: number;
}

/** Find duplicate target names before two external sources can overwrite each other. */
export function findManagedSkillConflicts(
	sources: readonly ManagedSkillSource[],
): string[] {
	const owners = new Map<string, string>();
	const conflicts = new Set<string>();

	for (const source of sources) {
		for (const skill of source.skills) {
			const owner = owners.get(skill.name);

			if (owner && owner !== source.displayName) {
				conflicts.add(`${skill.name}: ${owner}, ${source.displayName}`);
				continue;
			}

			owners.set(skill.name, source.displayName);
		}
	}

	return [...conflicts].toSorted();
}

/** Confirm every managed source file resolves through the shared skill path. */
export async function verifyManagedSkillDeployment(
	source: ManagedSkillSource,
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	const managedRoot = managedSkillRoot(dotfilesDir);
	const issues: string[] = [];
	const deploymentRoots = [
		{ label: "", path: resolve(homeDir, ".agents", "skills") },
		...(source.compatibilityRoots ?? []).map((root) => ({
			label: `${root}: `,
			path: resolve(homeDir, root),
		})),
	];

	for (const deploymentRoot of deploymentRoots) {
		for (const skill of source.skills) {
			const sourceRoot = resolve(managedRoot, skill.name);
			const deployedSkillRoot = resolve(deploymentRoot.path, skill.name);

			for await (
				const entry of walk(sourceRoot, {
					includeDirs: false,
					includeSymlinks: false,
				})
			) {
				const pathWithinSkill = relative(sourceRoot, entry.path);
				const deployedPath = resolve(deployedSkillRoot, pathWithinSkill);
				const issuePath =
					`${deploymentRoot.label}${skill.name}/${pathWithinSkill}`;

				if (!(await exists(deployedPath))) {
					issues.push(`${issuePath}: missing`);
					continue;
				}

				const [sourceRealPath, deployedRealPath] = await Promise.all([
					Deno.realPath(entry.path),
					Deno.realPath(deployedPath),
				]);

				if (sourceRealPath !== deployedRealPath) {
					issues.push(`${issuePath}: not dotfiles-managed`);
				}
			}
		}
	}

	return issues;
}

/** Fetch the latest selected skills and install them into the repository. */
export async function syncManagedSkills(
	source: ManagedSkillSource,
	dotfilesDir: string,
): Promise<ManagedSkillSyncResult> {
	const resolvedSha = await resolveSourceSha(source);
	const tempDir = await Deno.makeTempDir({ prefix: source.tempPrefix });
	const archivePath = join(tempDir, "source.tar.gz");
	const checkoutDir = join(tempDir, "checkout");

	try {
		await Deno.mkdir(checkoutDir, { recursive: true });
		await downloadArchive(source, resolvedSha, archivePath);
		await extractArchive(source, archivePath, checkoutDir);
		await installManagedSkillsFromCheckout(
			source,
			checkoutDir,
			dotfilesDir,
			resolvedSha,
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true }).catch(() => undefined);
	}

	return { resolvedSha, skillCount: source.skills.length };
}

/**
 * Replace one source's managed skill directories from an extracted checkout.
 *
 * Every replacement is staged before the first target changes. Existing
 * directories move to transaction-specific backups and are restored if any
 * later replacement fails.
 */
export async function installManagedSkillsFromCheckout(
	source: ManagedSkillSource,
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	assertCommitSha(source, resolvedSha);

	const managedRoot = managedSkillRoot(dotfilesDir);
	const transactionId = crypto.randomUUID();
	const staged: StagedSkill[] = [];

	await Deno.mkdir(managedRoot, { recursive: true });

	try {
		for (const skill of source.skills) {
			const skillSource = resolve(checkoutDir, skill.sourcePath);
			const skillFile = join(skillSource, "SKILL.md");
			const target = resolve(managedRoot, skill.name);
			const stage = resolve(
				managedRoot,
				`.${skill.name}.${source.transactionLabel}-next-${transactionId}`,
			);
			const backup = resolve(
				managedRoot,
				`.${skill.name}.${source.transactionLabel}-backup-${transactionId}`,
			);

			assertPathWithin(checkoutDir, skillSource);
			assertPathWithin(managedRoot, target);
			assertPathWithin(managedRoot, stage);
			assertPathWithin(managedRoot, backup);

			if (!(await exists(skillFile, { isFile: true }))) {
				throw new Error(
					`${source.displayName} skill is missing SKILL.md: ${skill.name}`,
				);
			}

			await copy(skillSource, stage, { overwrite: false });
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

		await writeManifest(source, managedRoot, transactionId, resolvedSha);

		for (const item of staged) {
			if (item.hadOriginal) {
				await removeManagedPath(managedRoot, item.backup);
			}
		}
	} catch (error) {
		await restoreStagedSkills(managedRoot, staged);

		throw error;
	}
}

function managedSkillRoot(dotfilesDir: string): string {
	return resolve(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);
}

async function restoreStagedSkills(
	managedRoot: string,
	staged: readonly StagedSkill[],
) {
	for (const item of staged.toReversed()) {
		if (item.replacementPlaced) {
			await removeManagedPath(managedRoot, item.target).catch(() => undefined);
		}

		if (item.hadOriginal && await exists(item.backup)) {
			await Deno.rename(item.backup, item.target).catch(() => undefined);
		}

		await removeManagedPath(managedRoot, item.stage).catch(() => undefined);
	}
}

async function resolveSourceSha(source: ManagedSkillSource): Promise<string> {
	const response = await fetch(
		`https://api.github.com/repos/${source.repository}/commits/${source.ref}`,
		{
			headers: {
				Accept: "application/vnd.github+json",
				"User-Agent": source.userAgent,
			},
		},
	);

	if (!response.ok) {
		throw new Error(
			`Failed to resolve ${source.displayName} ${source.ref}: HTTP ${response.status}`,
		);
	}

	const payload: unknown = await response.json();

	if (!isObject(payload) || typeof payload.sha !== "string") {
		throw new Error(
			`GitHub returned an invalid ${source.displayName} commit response`,
		);
	}

	assertCommitSha(source, payload.sha);

	return payload.sha;
}

async function downloadArchive(
	source: ManagedSkillSource,
	resolvedSha: string,
	archivePath: string,
) {
	const response = await fetch(
		`https://codeload.github.com/${source.repository}/tar.gz/${resolvedSha}`,
		{ headers: { "User-Agent": source.userAgent } },
	);

	if (!response.ok) {
		throw new Error(
			`Failed to download ${source.displayName}: HTTP ${response.status}`,
		);
	}

	await Deno.writeFile(
		archivePath,
		new Uint8Array(await response.arrayBuffer()),
	);
}

async function extractArchive(
	source: ManagedSkillSource,
	archivePath: string,
	checkoutDir: string,
) {
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

		throw new Error(
			`Failed to extract ${source.displayName} archive: ${stderr}`,
		);
	}
}

async function writeManifest(
	source: ManagedSkillSource,
	managedRoot: string,
	transactionId: string,
	resolvedSha: string,
) {
	const manifest: ManagedSkillManifest = {
		repository: `https://github.com/${source.repository}`,
		ref: source.ref,
		resolvedSha,
		skills: source.skills.map((skill) => skill.name),
		version: 1,
	};
	const target = resolve(managedRoot, source.manifestFile);
	const stage = resolve(
		managedRoot,
		`${source.manifestFile}.next-${transactionId}`,
	);

	assertPathWithin(managedRoot, target);
	assertPathWithin(managedRoot, stage);

	await Deno.writeTextFile(stage, `${JSON.stringify(manifest, null, "\t")}\n`);
	await Deno.rename(stage, target);
}

async function removeManagedPath(managedRoot: string, target: string) {
	assertPathWithin(managedRoot, target);

	if (await exists(target)) {
		await Deno.remove(target, { recursive: true });
	}
}

function assertPathWithin(root: string, target: string) {
	const pathFromRoot = relative(root, target);

	if (
		!pathFromRoot || pathFromRoot === "." || isAbsolute(pathFromRoot) ||
		pathFromRoot === ".." || pathFromRoot.startsWith(`..${separator()}`)
	) {
		throw new Error(`Refusing path outside the managed root: ${target}`);
	}
}

function separator(): string {
	return Deno.build.os === "windows" ? "\\" : "/";
}

function assertCommitSha(source: ManagedSkillSource, value: string) {
	if (!/^[0-9a-f]{40}$/.test(value)) {
		throw new Error(`Invalid ${source.displayName} commit SHA: ${value}`);
	}
}

function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}
