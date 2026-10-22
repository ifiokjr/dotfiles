import { assertEquals } from "@std/assert";
import { runCommand } from "../lib/config.ts";
import {
	ARTIFACT_DIR_NAMES,
	developerRoot,
	discoverWorktrees,
	isArtifactDirName,
	isDirtyWorktree,
	isGitIgnored,
	lastCommitMs,
	newestSourceMtime,
	parseWorktreeList,
	planStaleArtifacts,
	scanArtifactTree,
} from "../lib/devscan.ts";

/** Deterministic old timestamp: pinned to the second, 40 days before today. */
const OLD_MS = Math.floor((Date.now() - 40 * 24 * 60 * 60 * 1000) / 1000) *
	1000;
const old = new Date(OLD_MS);
const CUTOFF_MS = Date.now() - 30 * 24 * 60 * 60 * 1000;

/** Run git in `cwd`, failing the test loudly instead of corrupting fixtures. */
async function git(
	cwd: string,
	args: string[],
	env?: Record<string, string>,
): Promise<string> {
	const { success, stdout, code } = await runCommand(["git", ...args], {
		cwd,
		env,
		stdout: "piped",
		stderr: "null",
	});
	if (!success) {
		throw new Error(`git ${args.join(" ")} failed with code ${code}`);
	}
	return stdout ?? "";
}

/** git init + an initial commit; `when` pins the commit's author/committer date. */
async function initRepo(dir: string, when?: Date): Promise<void> {
	await Deno.mkdir(dir, { recursive: true });
	await git(dir, ["init", "--initial-branch=main"]);
	const env = when
		? {
			GIT_AUTHOR_DATE: when.toISOString(),
			GIT_COMMITTER_DATE: when.toISOString(),
		}
		: undefined;
	await git(dir, [
		"-c",
		"user.name=Test",
		"-c",
		"user.email=test@example.com",
		"commit",
		"--allow-empty",
		"-m",
		"init",
	], env);
}

function ageDirAndContents(path: string): void {
	Deno.utimeSync(path, old, old);
	for (const entry of Deno.readDirSync(path)) {
		const child = `${path}/${entry.name}`;
		try {
			Deno.utimeSync(child, old, old);
		} catch (error) {
			// Git runs background maintenance (gc/maintenance) after repo
			// init and can delete lock files between the readDir and the
			// utime; a vanished helper path is not a test failure.
			if (!(error instanceof Deno.errors.NotFound)) throw error;
		}
		if (entry.isDirectory) ageDirAndContents(child);
	}
}

Deno.test("developerRoot is ~/Developer", () => {
	const home = Deno.env.get("HOME") ?? "/tmp";
	assertEquals(developerRoot(), `${home}/Developer`);
});

Deno.test("artifact names cover the common toolchains but not shipped output", () => {
	for (
		const name of [
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
		]
	) {
		assertEquals(isArtifactDirName(name), true, name);
	}
	// `dist` is shipped output, `target` belongs to cargo-clean-all, `vendor`
	// may be committed source, and `src` is source.
	assertEquals(isArtifactDirName("dist"), false);
	assertEquals(isArtifactDirName("target"), false);
	assertEquals(isArtifactDirName("vendor"), false);
	assertEquals(isArtifactDirName("src"), false);
	assertEquals(ARTIFACT_DIR_NAMES.includes("node_modules"), true);
});

Deno.test("scanArtifactTree collects artifacts without descending into them", async () => {
	const root = await Deno.makeTempDir({ prefix: "devscan-tree-" });
	try {
		await Deno.mkdir(`${root}/projA/node_modules/dep/node_modules`, {
			recursive: true,
		});
		await Deno.mkdir(`${root}/projA/build`, { recursive: true });
		await Deno.mkdir(`${root}/projA/src`, { recursive: true });
		await Deno.mkdir(`${root}/projA/.git/objects`, { recursive: true });
		await Deno.mkdir(`${root}/projB/packages/app/node_modules/x`, {
			recursive: true,
		});
		await Deno.mkdir(`${root}/projB/packages/app/build`, { recursive: true });
		await Deno.mkdir(`${root}/projC/dist`, { recursive: true });

		const { hits } = await scanArtifactTree(root);
		const paths = hits.map((hit) => hit.path).toSorted();
		assertEquals(paths, [
			`${root}/projA/build`,
			`${root}/projA/node_modules`,
			`${root}/projB/packages/app/build`,
			`${root}/projB/packages/app/node_modules`,
		]);
		for (const hit of hits) {
			assertEquals(hit.parent, hit.path.slice(0, hit.path.lastIndexOf("/")));
			assertEquals(hit.name, hit.path.split("/").pop());
		}
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});

Deno.test("scanArtifactTree activity ignores artifact mtimes but honors source edits", async () => {
	const root = await Deno.makeTempDir({ prefix: "devscan-age-" });
	try {
		// Dormant project: only a fresh install touched it — the install must
		// not count as activity, so the project still reads as dormant.
		await Deno.mkdir(`${root}/dormant/node_modules/dep`, { recursive: true });
		await Deno.mkdir(`${root}/dormant/src`, { recursive: true });
		await Deno.writeTextFile(`${root}/dormant/src/main.dart`, "void main() {}");
		ageDirAndContents(`${root}/dormant/src`);
		// Active project: a fresh source edit is the signal to keep artifacts.
		await Deno.mkdir(`${root}/active/node_modules`, { recursive: true });
		await Deno.mkdir(`${root}/active/src`, { recursive: true });
		await Deno.writeTextFile(`${root}/active/src/main.dart`, "void main() {}");

		const scan = await scanArtifactTree(root);
		const dormant = scan.activity.get(`${root}/dormant`);
		const active = scan.activity.get(`${root}/active`);
		assertEquals(dormant !== undefined && dormant < CUTOFF_MS, true);
		assertEquals(active !== undefined && active >= CUTOFF_MS, true);
		// The same signal standalone: fresh checkouts and uncommitted edits
		// read as touched even when artifacts (and commits) are old.
		const dormantTouched = await newestSourceMtime(`${root}/dormant`);
		assertEquals(dormantTouched !== null && dormantTouched < CUTOFF_MS, true);
		assertEquals(
			scan.rootNewest !== null && scan.rootNewest >= CUTOFF_MS,
			true,
		);
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});

Deno.test("isGitIgnored reads git's own exclude rules", async () => {
	const root = await Deno.makeTempDir({ prefix: "devscan-ignore-" });
	try {
		const repo = `${root}/repo`;
		await initRepo(repo);
		await Deno.writeTextFile(`${repo}/.gitignore`, "node_modules/\n");
		await Deno.mkdir(`${repo}/node_modules`, { recursive: true });
		await Deno.mkdir(`${repo}/tracked`, { recursive: true });
		await Deno.writeTextFile(`${repo}/tracked/keep.txt`, "x");
		await git(repo, ["add", ".gitignore", "tracked"]);
		await git(repo, [
			"-c",
			"user.name=Test",
			"-c",
			"user.email=test@example.com",
			"commit",
			"-m",
			"ignore rules",
		]);

		assertEquals(await isGitIgnored(repo, "node_modules"), true);
		assertEquals(await isGitIgnored(repo, "tracked"), false);
		// Outside any repo there is nothing to delete.
		assertEquals(await isGitIgnored(root, "node_modules"), false);
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});

Deno.test("planStaleArtifacts keeps active projects, ignores committed dirs", async () => {
	const root = await Deno.makeTempDir({ prefix: "devscan-plan-" });
	try {
		const dormant = `${root}/dormant`;
		await initRepo(dormant);
		await Deno.writeTextFile(`${dormant}/.gitignore`, "node_modules/\n");
		await Deno.mkdir(`${dormant}/node_modules`, { recursive: true });
		await Deno.mkdir(`${dormant}/src`, { recursive: true });
		await Deno.writeTextFile(`${dormant}/src/main.dart`, "void main() {}");
		ageDirAndContents(dormant);

		const active = `${root}/active`;
		await initRepo(active);
		await Deno.writeTextFile(`${active}/.gitignore`, "node_modules/\n");
		await Deno.mkdir(`${active}/node_modules`, { recursive: true });

		const committed = `${root}/committed`;
		await initRepo(committed);
		await Deno.writeTextFile(`${committed}/.gitignore`, "node_modules/\n");
		await Deno.mkdir(`${committed}/build`, { recursive: true });
		await Deno.writeTextFile(`${committed}/build/steps.js`, "export {};");
		await Deno.mkdir(`${committed}/src`, { recursive: true });
		await Deno.writeTextFile(`${committed}/src/main.js`, "");
		await git(committed, ["add", "build"]);
		await git(committed, [
			"-c",
			"user.name=Test",
			"-c",
			"user.email=test@example.com",
			"commit",
			"-m",
			"committed build dir",
		]);
		ageDirAndContents(committed);

		const plain = `${root}/plain`;
		await Deno.mkdir(`${plain}/node_modules`, { recursive: true });
		await Deno.mkdir(`${plain}/src`, { recursive: true });
		ageDirAndContents(plain);

		const plan = await planStaleArtifacts(root, CUTOFF_MS);
		assertEquals(plan.stale.map((hit) => hit.path), [
			`${dormant}/node_modules`,
		]);
		assertEquals(plan.keptActive, 1);
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});

Deno.test("parseWorktreeList reads porcelain fields", () => {
	const porcelain = [
		"worktree /dev/repo",
		"HEAD 1111111111111111111111111111111111111111",
		"branch refs/heads/main",
		"",
		"worktree /dev/repo-wt",
		"HEAD 2222222222222222222222222222222222222222",
		"detached",
		"",
		"worktree /dev/repo-locked",
		"HEAD 3333333333333333333333333333333333333333",
		"branch refs/heads/feat/x",
		"locked user asked to keep",
		"",
		"worktree /dev/bare.git",
		"HEAD 4444444444444444444444444444444444444444",
		"bare",
		"",
	].join("\n");

	const parsed = parseWorktreeList(porcelain);
	assertEquals(parsed.length, 4);
	assertEquals(parsed[0], {
		path: "/dev/repo",
		main: "/dev/repo",
		branch: "main",
		bare: false,
		locked: false,
	});
	assertEquals(parsed[1].branch, null);
	assertEquals(parsed[1].main, "/dev/repo");
	assertEquals(parsed[2].branch, "feat/x");
	assertEquals(parsed[2].locked, true);
	assertEquals(parsed[3].bare, true);
	assertEquals(parseWorktreeList("not porcelain\n").length, 0);
});

Deno.test("discoverWorktrees finds and dedupes worktrees under a root", async () => {
	// git reports canonical paths, so the temp root must match — on macOS
	// /var/folders is a symlink to /private/var/folders.
	const root = await Deno.realPath(
		await Deno.makeTempDir({ prefix: "devscan-wt-" }),
	);
	try {
		const repo = `${root}/repo`;
		await initRepo(repo, old);
		await git(repo, ["worktree", "add", "-b", "feat/old", `${root}/wt-old`]);
		await git(`${root}/wt-old`, [
			"-c",
			"user.name=Test",
			"-c",
			"user.email=test@example.com",
			"commit",
			"--allow-empty",
			"-m",
			"old work",
		], {
			GIT_AUTHOR_DATE: new Date(OLD_MS).toISOString(),
			GIT_COMMITTER_DATE: new Date(OLD_MS).toISOString(),
		});

		// The main checkout and the linked worktree both appear as checkouts;
		// both report the same worktree set, which must dedupe to two entries.
		const discovered = await discoverWorktrees(root);
		assertEquals(discovered.map((wt) => wt.path).toSorted(), [
			`${root}/repo`,
			`${root}/wt-old`,
		]);
		assertEquals(discovered.every((wt) => wt.main === `${root}/repo`), true);
		assertEquals(
			discovered.find((wt) => wt.path === `${root}/repo`)?.branch,
			"main",
		);
		assertEquals(
			discovered.find((wt) => wt.path === `${root}/wt-old`)?.branch,
			"feat/old",
		);

		assertEquals(await lastCommitMs(`${root}/wt-old`), OLD_MS);
		assertEquals(await isDirtyWorktree(`${root}/wt-old`), false);
		await Deno.writeTextFile(`${root}/wt-old/scratch.txt`, "wip");
		assertEquals(await isDirtyWorktree(`${root}/wt-old`), true);
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});
