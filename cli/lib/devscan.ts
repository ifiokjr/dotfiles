/**
 * Scans development trees (`~/Developer`) for regenerable build artifacts and
 * stale git worktrees — the two things that quietly consume tens of GB there.
 *
 * Safety rules that hold the whole module together:
 *
 * - Only directories git itself excludes are deletable. `git check-ignore` is
 *   the gate, so a repo that commits its `build/` (or vendored sources under a
 *   matching name) is never touched, and neither is anything outside a repo.
 * - Artifacts are gated by their project's *source* activity, not the
 *   artifacts' own mtimes: builds and installs refresh artifact mtimes while
 *   leaving source untouched, so a project that was merely built months ago
 *   still counts as dormant.
 * - Symlinks are never followed, recorded, or deleted — a linked `build`
 *   points somewhere that deleting would be a surprise.
 */

import { runCommand } from "./config.ts";

/** Default root scanned for projects and worktrees. */
export function developerRoot(): string {
	const home = Deno.env.get("HOME") ?? "/tmp";
	return `${home}/Developer`;
}

/**
 * Directory names treated as regenerable build artifacts.
 *
 * Deliberately absent: `dist` and friends hold shipped output the user may
 * want to keep; `target` is owned by `cargo-clean-all` under the clean command's
 * `cargo` category, not this walker; `vendor` can be committed source in C/PHP
 * projects, and while the git-ignore gate would protect the committed ones,
 * the name is too ambiguous to bother with.
 */
export const ARTIFACT_DIR_NAMES = [
	"node_modules",
	"build",
	"Pods",
	".dart_tool",
	".gradle",
	".expo",
	".next",
	".nuxt",
	".turbo",
	".cache",
	"coverage",
	".venv",
	"__pycache__",
	"playwright-report",
	"test-results",
] as const;

const artifactNames = new Set<string>(ARTIFACT_DIR_NAMES);

export function isArtifactDirName(name: string): boolean {
	return artifactNames.has(name);
}

export interface ArtifactHit {
	/** Absolute path of the artifact directory. */
	path: string;
	/** The directory containing it — the project whose activity gates it. */
	parent: string;
	/** The artifact directory's own name (always `basename(path)`). */
	name: string;
}

export interface ArtifactScan {
	hits: ArtifactHit[];
	/**
	 * Newest source mtime (ms) per directory that directly contains an artifact
	 * hit — the activity signal the age gate checks against.
	 */
	activity: Map<string, number>;
	/** Newest source mtime (ms) anywhere under the scanned root, or null. */
	rootNewest: number | null;
}

/** `du -sk`, returning bytes or null when the path is missing. */
export async function duBytes(path: string): Promise<number | null> {
	const { success, stdout } = await runCommand(["du", "-sk", path], {
		stdout: "piped",
		stderr: "null",
	});
	if (!success || !stdout) return null;
	const kb = Number.parseInt(stdout.split("\t")[0], 10);
	return Number.isFinite(kb) ? kb * 1024 : null;
}

/** Whether a path exists; verifies that a privileged removal really landed. */
export async function pathExists(path: string): Promise<boolean> {
	try {
		await Deno.lstat(path);
		return true;
	} catch {
		return false;
	}
}

/**
 * Walk a development tree once, collecting artifact directories and the newest
 * source mtime of every directory that contains one.
 *
 * Artifact directories and `.git` are recorded/pruned rather than descended
 * into: their contents are exactly the bulk being measured for deletion, and
 * walking them (or counting their mtimes as project activity) would both slow
 * the scan and corrupt the age gate.
 */
export async function scanArtifactTree(root: string): Promise<ArtifactScan> {
	const hits: ArtifactHit[] = [];
	const subtreeNewest = new Map<string, number>();

	async function visit(dir: string): Promise<number | null> {
		let newest: number | null = null;
		let entries: AsyncIterable<Deno.DirEntry>;
		try {
			entries = Deno.readDir(dir);
		} catch {
			// Unreadable (e.g. root-owned); treat as having no source activity.
			return null;
		}
		for await (const entry of entries) {
			if (entry.isSymlink) continue;
			if (entry.isDirectory && isArtifactDirName(entry.name)) {
				hits.push({
					path: `${dir}/${entry.name}`,
					parent: dir,
					name: entry.name,
				});
				continue;
			}
			if (entry.isDirectory && entry.name === ".git") continue;
			let mtime: number | null = null;
			try {
				mtime = (await Deno.lstat(`${dir}/${entry.name}`)).mtime?.getTime() ??
					null;
			} catch {
				// Entry vanished mid-walk.
			}
			if (entry.isDirectory) {
				const deepest = Math.max(
					mtime ?? 0,
					(await visit(`${dir}/${entry.name}`)) ?? 0,
				);
				mtime = deepest === 0 ? null : deepest;
			}
			if (mtime !== null && (newest === null || mtime > newest)) newest = mtime;
		}
		if (newest !== null) subtreeNewest.set(dir, newest);
		return newest;
	}

	const rootNewest = await visit(root);
	const activity = new Map<string, number>();
	for (const hit of hits) {
		const newest = subtreeNewest.get(hit.parent);
		if (newest !== undefined) activity.set(hit.parent, newest);
	}
	return { hits, activity, rootNewest };
}

/**
 * When a directory's source was last touched: the newest mtime of any
 * non-artifact, non-`.git` entry under it.
 *
 * `git worktree add` rewrites file mtimes on checkout, so a fresh worktree
 * taken from an old branch reads as recently touched — and so do uncommitted
 * edits, which is exactly what the worktree age gate must not delete.
 */
export async function newestSourceMtime(dir: string): Promise<number | null> {
	return (await scanArtifactTree(dir)).rootNewest;
}

/** Whether git excludes `relativePath` (from inside `projectDir`); false outside any repo. */
export async function isGitIgnored(
	projectDir: string,
	relativePath: string,
): Promise<boolean> {
	const { code } = await runCommand(
		["git", "-C", projectDir, "check-ignore", "-q", "--", relativePath],
		{ stdout: "null", stderr: "null" },
	);
	return code === 0;
}

export interface StaleArtifactPlan {
	/** Artifact dirs whose project is dormant and which git ignores. */
	stale: ArtifactHit[];
	/** Artifact dirs whose project's source changed after the cutoff. */
	keptActive: number;
}

/**
 * Decide which artifact directories under `root` may be deleted: the project
 * holding each one has had no source change since `cutoffMs`, and git confirms
 * the directory is ignored. Everything else is either kept or not deletable.
 */
export async function planStaleArtifacts(
	root: string,
	cutoffMs: number,
): Promise<StaleArtifactPlan> {
	const scan = await scanArtifactTree(root);
	const stale: ArtifactHit[] = [];
	let keptActive = 0;

	for (const hit of scan.hits) {
		const newest = scan.activity.get(hit.parent);
		if (newest !== undefined && newest > cutoffMs) {
			keptActive++;
			continue;
		}
		if (await isGitIgnored(hit.parent, hit.name)) stale.push(hit);
	}
	return { stale, keptActive };
}

export interface ParsedWorktree {
	/** The worktree checkout path. */
	path: string;
	/** The repository's main worktree — the first entry git reports. */
	main: string;
	/** Branch ref without `refs/heads/`, or null when detached. */
	branch: string | null;
	bare: boolean;
	locked: boolean;
}

/** Parse `git worktree list --porcelain` output into one record per worktree. */
export function parseWorktreeList(porcelain: string): ParsedWorktree[] {
	const parsed: ParsedWorktree[] = [];
	let main: string | null = null;

	for (const block of porcelain.split("\n\n")) {
		let path: string | null = null;
		let branch: string | null = null;
		let bare = false;
		let locked = false;

		for (const line of block.split("\n")) {
			if (line.startsWith("worktree ")) {
				path = line.slice("worktree ".length).trim();
			} else if (line.startsWith("branch ")) {
				branch = line.slice("branch ".length).replace(/^refs\/heads\//, "");
			} else if (line === "bare") {
				bare = true;
			} else if (line.startsWith("locked")) {
				locked = true;
			}
		}
		if (!path) continue;
		if (main === null) main = path;
		parsed.push({ path, main, branch, bare, locked });
	}
	return parsed;
}

/** Directories under `root` that are git checkouts (repo or linked worktree). */
async function findGitCheckouts(root: string): Promise<string[]> {
	const checkouts: string[] = [];

	async function visit(dir: string): Promise<void> {
		let entries: AsyncIterable<Deno.DirEntry>;
		try {
			entries = Deno.readDir(dir);
		} catch {
			return;
		}
		for await (const entry of entries) {
			if (entry.isDirectory && isArtifactDirName(entry.name)) continue;
			if (entry.name === ".git") {
				// A `.git` file marks a linked worktree; a directory, a repo root.
				checkouts.push(dir);
				continue;
			}
			if (!entry.isDirectory || entry.isSymlink) continue;
			await visit(`${dir}/${entry.name}`);
		}
	}

	await visit(root);
	return checkouts;
}

/**
 * Every git worktree registered by any checkout under `root`, deduplicated by
 * path. Repos under `root` can register worktrees anywhere on disk, and a
 * linked worktree can itself live under `root` for a repo elsewhere, so this
 * discovers from both directions.
 */
export async function discoverWorktrees(
	root: string,
): Promise<ParsedWorktree[]> {
	const seen = new Set<string>();
	const worktrees: ParsedWorktree[] = [];

	for (const checkout of await findGitCheckouts(root)) {
		const { success, stdout } = await runCommand(
			["git", "-C", checkout, "worktree", "list", "--porcelain"],
			{ stdout: "piped", stderr: "null" },
		);
		if (!success || !stdout) continue;
		for (const wt of parseWorktreeList(stdout)) {
			if (seen.has(wt.path)) continue;
			seen.add(wt.path);
			worktrees.push(wt);
		}
	}
	return worktrees;
}

/**
 * The epoch ms of a path's last commit, falling back to its directory mtime
 * for checkouts with no commits yet (an empty worktree is fresh, not stale).
 */
export async function lastCommitMs(path: string): Promise<number | null> {
	const { success, stdout } = await runCommand(
		["git", "-C", path, "log", "-1", "--format=%ct", "HEAD"],
		{ stdout: "piped", stderr: "null" },
	);
	const seconds = success ? Number.parseInt((stdout ?? "").trim(), 10) : NaN;
	if (Number.isFinite(seconds) && seconds > 0) return seconds * 1000;
	try {
		return (await Deno.lstat(path)).mtime?.getTime() ?? null;
	} catch {
		return null;
	}
}

/** Whether a checkout has uncommitted changes (tracked edits or untracked files). */
export async function isDirtyWorktree(path: string): Promise<boolean> {
	const { success, stdout } = await runCommand(
		["git", "-C", path, "status", "--porcelain"],
		{ stdout: "piped", stderr: "null" },
	);
	return success && (stdout ?? "").trim().length > 0;
}
