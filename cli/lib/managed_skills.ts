import { copy, exists, walk } from "@std/fs";
import { isAbsolute, join, relative, resolve } from "@std/path";

export interface ManagedSkillSpec {
	name: string;
	sourcePath: string;
}

export interface ManagedSkillSource {
	/**
	 * Where to track the source. "branch" (the default) follows the head of
	 * `ref`; "release" follows the repository's latest full GitHub release,
	 * so skill content always matches a released package version.
	 */
	channel?: "branch" | "release";
	compatibilityRoots?: readonly string[];
	displayName: string;
	manifestFile: string;
	repository: string;
	ref: string;
	skills: readonly ManagedSkillSpec[];
	/**
	 * Directory inside the checkout that holds one skill per child directory.
	 *
	 * When set, a sync discovers the skills that directory actually contains
	 * instead of trusting the static `skills` list, so the collection mirrors
	 * upstream: skills added there are picked up by the next `dot rebuild
	 * --update` and skills removed there are dropped. The static list remains
	 * the seed for a checkout that has never synced; after a successful sync
	 * the manifest is authoritative, and this source's `skills` is updated in
	 * place so conflict checks and deployment verification in the same process
	 * cover the discovered set.
	 */
	skillsDirectory?: string;
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

interface ResolvedSource {
	ref: string;
	sha: string;
}

interface StagedSkill {
	backup: string;
	hadOriginal: boolean;
	replacementPlaced: boolean;
	stage: string;
	target: string;
}

export interface ManagedSkillSyncResult {
	resolvedRef: string;
	resolvedSha: string;
	skillCount: number;
	/** Skill names the sync installed, sorted. */
	skills: readonly string[];
}

/**
 * Skills to leave alone because their collection is toggled off.
 *
 * A disabled skill stays in the repository but is stripped from the deployed
 * harness links, so verification must not expect it at the deployed path.
 */
export interface ManagedSkillOptions {
	skipSkills?: ReadonlySet<string>;
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

/**
 * Remove deployed links that point into the dotfiles checkout but no longer
 * resolve, and return their paths.
 *
 * Tuckr's linker is deliberately conservative: a destination that exists is
 * skipped and a dangling symlink only produces a failed symlink call, so
 * deployed state stops converging whenever the repository moves a managed
 * skill — the old per-file links dangle, and deployment verification reports
 * them "missing" on every run. Pruning the broken ones before
 * `tuckr set --only-files` runs lets that pass recreate them at the current
 * location; the same pass also cleans up links left dangling by a file a
 * source retired.
 *
 * A link is removed only when it is a symlink into this checkout's agents
 * group whose target is gone, so user-installed skills, real files, and
 * intact deployments are never touched.
 */
export async function repairAgentSkillDeployment(
	homeDir: string,
): Promise<string[]> {
	const pruned: string[] = [];

	for (const root of deployedSkillRoots(homeDir)) {
		if (!(await exists(root))) continue;
		await pruneDanglingLinksIn(root, pruned);
	}

	return pruned;
}

/** The harness skill roots tuckr populates for the agents group. */
function deployedSkillRoots(homeDir: string): string[] {
	return [
		resolve(homeDir, ".agents", "skills"),
		resolve(homeDir, ".pi", "agent", "skills"),
	];
}

/** True when a link target points into this checkout's agents group. */
function isCheckoutLinkTarget(target: string): boolean {
	return target.includes(
		`${separator()}Configs${separator()}agents${separator()}`,
	);
}

/** Recursively remove dangling links that point into this checkout. */
async function pruneDanglingLinksIn(dir: string, pruned: string[]) {
	for await (const entry of Deno.readDir(dir)) {
		const path = resolve(dir, entry.name);

		// Symlinks are checked before directories: readDir reports a
		// symlink-to-directory as both, and its contents must not be visited —
		// they belong to wherever the link resolves.
		if (entry.isSymlink) {
			const target = await Deno.readLink(path);

			if (!isCheckoutLinkTarget(target)) continue;
			if (await linkResolves(path)) continue;

			await Deno.remove(path);
			pruned.push(path);
			continue;
		}

		if (entry.isDirectory) {
			await pruneDanglingLinksIn(path, pruned);
		}
	}
}

async function linkResolves(path: string): Promise<boolean> {
	try {
		await Deno.realPath(path);
		return true;
	} catch {
		return false;
	}
}

/** Confirm every managed source file resolves through the shared skill path. */
export async function verifyManagedSkillDeployment(
	source: ManagedSkillSource,
	dotfilesDir: string,
	homeDir: string,
	opts: ManagedSkillOptions = {},
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
			// A disabled collection is deliberately not deployed, so its absence
			// from the harness roots is expected rather than a failure.
			if (opts.skipSkills?.has(skill.name)) continue;

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
	const resolved = await resolveSource(source);
	const tempDir = await Deno.makeTempDir({ prefix: source.tempPrefix });
	const archivePath = join(tempDir, "source.tar.gz");
	const checkoutDir = join(tempDir, "checkout");

	try {
		await Deno.mkdir(checkoutDir, { recursive: true });
		await downloadArchive(source, resolved.sha, archivePath);
		await extractArchive(source, archivePath, checkoutDir);

		const skills = source.skillsDirectory
			? await discoverSkills(source, checkoutDir, dotfilesDir)
			: source.skills;

		// Read before the install rewrites the manifest: the names it recorded
		// before this sync are what tells a discovery source which skills
		// upstream retired.
		const retired = source.skillsDirectory
			? await retiredSkillNames(source, dotfilesDir, skills)
			: [];

		await installManagedSkillsFromCheckout(
			{ ...source, skills },
			checkoutDir,
			dotfilesDir,
			resolved.sha,
			resolved.ref,
		);

		if (source.skillsDirectory) {
			const managedRoot = managedSkillRoot(dotfilesDir);

			for (const name of retired) {
				await removeManagedPath(managedRoot, resolve(managedRoot, name));
			}

			// Conflict checks and deployment verification read the source's skill
			// list, so point it at what upstream actually ships and they cover
			// skills upstream added since the static list was written.
			source.skills = skills;
		}

		return {
			resolvedRef: resolved.ref,
			resolvedSha: resolved.sha,
			skillCount: skills.length,
			skills: skills.map((skill) => skill.name),
		};
	} finally {
		await Deno.remove(tempDir, { recursive: true }).catch(() => undefined);
	}
}

/**
 * Enumerate the skills a discovery source ships in its checkout.
 *
 * A child directory of `skillsDirectory` counts as a skill when it holds a
 * SKILL.md — the same rule the Claude deploy hook uses to skip non-skills —
 * so a stray assets directory upstream cannot fail every future update. The
 * names are sorted so the manifest stays stable across runs.
 *
 * The managed skills root is shared with locally authored skills and the
 * other collections, so a discovered name that collides with an existing
 * directory this source does not own fails loudly instead of replacing it.
 * Ownership is the union of the source's manifest and its static list: the
 * manifest covers skills upstream added since the static snapshot was
 * written, and the static list covers a checkout whose manifest is missing.
 */
async function discoverSkills(
	source: ManagedSkillSource,
	checkoutDir: string,
	dotfilesDir: string,
): Promise<readonly ManagedSkillSpec[]> {
	const root = resolve(checkoutDir, source.skillsDirectory!);

	if (!(await exists(root, { isDirectory: true }))) {
		throw new Error(
			`${source.displayName} checkout is missing its skills directory: ${source.skillsDirectory}`,
		);
	}

	const owned = new Set([
		...(await manifestSkillNames(source, dotfilesDir)),
		...source.skills.map((skill) => skill.name),
	]);
	const managedRoot = managedSkillRoot(dotfilesDir);
	const specs: ManagedSkillSpec[] = [];

	for await (const entry of Deno.readDir(root)) {
		if (!entry.isDirectory) continue;

		const skillDir = resolve(root, entry.name);

		if (!(await exists(join(skillDir, "SKILL.md"), { isFile: true }))) {
			continue;
		}

		if (
			!owned.has(entry.name) && await exists(resolve(managedRoot, entry.name))
		) {
			throw new Error(
				`${source.displayName} ships a skill named ${entry.name}, but the managed skills root already holds a directory of that name this source does not own; resolve the collision before updating`,
			);
		}

		specs.push({
			name: entry.name,
			sourcePath: `${source.skillsDirectory}/${entry.name}`,
		});
	}

	if (specs.length === 0 && owned.size > 0) {
		throw new Error(
			`${source.displayName} sync found no skills under ${source.skillsDirectory}; refusing to empty the managed collection in case upstream moved its skills directory`,
		);
	}

	return specs.toSorted((a, b) => a.name.localeCompare(b.name));
}

/**
 * Skills the source previously installed that this checkout no longer ships.
 *
 * This is what makes a discovery source a mirror rather than an accumulator:
 * its managed set equals upstream's skill list. Only names recorded in the
 * source's own manifest are eligible, so locally authored skills and the
 * other collections are never touched.
 */
async function retiredSkillNames(
	source: ManagedSkillSource,
	dotfilesDir: string,
	discovered: readonly ManagedSkillSpec[],
): Promise<readonly string[]> {
	const keep = new Set(discovered.map((skill) => skill.name));

	return (await manifestSkillNames(source, dotfilesDir)).filter((name) =>
		!keep.has(name)
	);
}

/**
 * Skill names recorded in the source's manifest, or an empty list.
 *
 * A missing or unreadable manifest is not an error: callers use the result to
 * widen ownership or prune retired skills, and a checkout that has never
 * synced simply has nothing recorded yet.
 */
export async function manifestSkillNames(
	source: ManagedSkillSource,
	dotfilesDir: string,
): Promise<readonly string[]> {
	try {
		const manifest = JSON.parse(
			await Deno.readTextFile(
				join(managedSkillRoot(dotfilesDir), source.manifestFile),
			),
		) as { skills?: unknown };

		return Array.isArray(manifest.skills)
			? manifest.skills.filter((name): name is string =>
				typeof name === "string"
			)
			: [];
	} catch {
		return [];
	}
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
	resolvedRef: string = source.ref,
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

		await writeManifest(source, managedRoot, transactionId, {
			ref: resolvedRef,
			sha: resolvedSha,
		});

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

/** The managed skills root, within a dotfiles checkout. */
export function managedSkillRoot(dotfilesDir: string): string {
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

/** Resolve the ref a source tracks, then pin it to an exact commit. */
async function resolveSource(
	source: ManagedSkillSource,
): Promise<ResolvedSource> {
	const ref = source.channel === "release"
		? await resolveLatestRelease(source)
		: source.ref;
	const sha = await resolveSourceSha(source, ref);

	return { ref, sha };
}

/** Resolve the repository's latest full GitHub release to its tag name. */
async function resolveLatestRelease(
	source: ManagedSkillSource,
): Promise<string> {
	const response = await fetch(
		`https://api.github.com/repos/${source.repository}/releases/latest`,
		{
			headers: {
				Accept: "application/vnd.github+json",
				"User-Agent": source.userAgent,
			},
		},
	);

	if (!response.ok) {
		throw new Error(
			`Failed to resolve the latest ${source.displayName} release: HTTP ${response.status}`,
		);
	}

	const payload: unknown = await response.json();

	if (
		!isObject(payload) || typeof payload.tag_name !== "string" ||
		payload.tag_name === ""
	) {
		throw new Error(
			`GitHub returned an invalid ${source.displayName} release response`,
		);
	}

	return payload.tag_name;
}

async function resolveSourceSha(
	source: ManagedSkillSource,
	ref: string,
): Promise<string> {
	const response = await fetch(
		`https://api.github.com/repos/${source.repository}/commits/${ref}`,
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
	resolved: ResolvedSource,
) {
	const manifest: ManagedSkillManifest = {
		repository: `https://github.com/${source.repository}`,
		ref: resolved.ref,
		resolvedSha: resolved.sha,
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
