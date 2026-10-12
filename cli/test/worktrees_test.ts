import { assertEquals } from "@std/assert";
import { findStaleWorktrees, removeWorktree } from "../commands/worktrees.ts";
import { runCommand } from "../lib/config.ts";
import { discoverWorktrees, pathExists } from "../lib/devscan.ts";

/** Deterministic old timestamp: pinned to the second, 40 days before today. */
const OLD_MS = Math.floor((Date.now() - 40 * 24 * 60 * 60 * 1000) / 1000) *
	1000;
const old = new Date(OLD_MS);

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

async function initRepo(dir: string, when: Date): Promise<void> {
	await Deno.mkdir(dir, { recursive: true });
	await git(dir, ["init", "--initial-branch=main"]);
	await commit(dir, "init", when);
}

async function commit(cwd: string, message: string, when: Date): Promise<void> {
	await git(cwd, [
		"-c",
		"user.name=Test",
		"-c",
		"user.email=test@example.com",
		"commit",
		"--allow-empty",
		"-m",
		message,
	], {
		GIT_AUTHOR_DATE: when.toISOString(),
		GIT_COMMITTER_DATE: when.toISOString(),
	});
}

/** Create a worktree of `repo` whose last commit is dated `when`. */
async function addWorktree(
	repo: string,
	path: string,
	branch: string,
	when: Date,
): Promise<void> {
	await git(repo, ["worktree", "add", "-b", branch, path]);
	await commit(path, "worktree work", when);
}

/** Simulate a checkout that has sat untouched since `old`. */
function ageDirAndContents(path: string): void {
	Deno.utimeSync(path, old, old);
	for (const entry of Deno.readDirSync(path)) {
		const child = `${path}/${entry.name}`;
		Deno.utimeSync(child, old, old);
		if (entry.isDirectory) ageDirAndContents(child);
	}
}

Deno.test("findStaleWorktrees partitions by commits, file changes, cwd, and liveness", async () => {
	// git reports canonical paths, so the temp root must match — on macOS
	// /var/folders is a symlink to /private/var/folders.
	const root = await Deno.realPath(
		await Deno.makeTempDir({ prefix: "worktrees-plan-" }),
	);
	try {
		const repo = `${root}/repo`;
		await initRepo(repo, old);
		await addWorktree(repo, `${root}/wt-old`, "feat/old", old);
		ageDirAndContents(`${root}/wt-old`);
		await addWorktree(repo, `${root}/wt-new`, "feat/new", new Date());
		// Checked out just now from a branch whose tip is old: the checkout
		// rewrites file mtimes, so it must read as touched, not stale.
		await addWorktree(repo, `${root}/wt-fresh-checkout`, "feat/fresh", old);
		// Untouched for months, but it holds a fresh uncommitted edit.
		await addWorktree(repo, `${root}/wt-edited`, "feat/edited", old);
		ageDirAndContents(`${root}/wt-edited`);
		await Deno.writeTextFile(`${root}/wt-edited/scratch.dart`, "// wip");

		const discovered = await discoverWorktrees(root);

		const fromOutside = await findStaleWorktrees(discovered, root, 30);
		assertEquals(fromOutside.stale.map((wt) => wt.path), [`${root}/wt-old`]);
		assertEquals(fromOutside.stale[0].branch, "feat/old");
		assertEquals(fromOutside.stale[0].locked, false);
		assertEquals(fromOutside.active, 3);
		assertEquals(fromOutside.prunable, []);

		// Standing inside the stale worktree must protect it.
		const fromInside = await findStaleWorktrees(
			discovered,
			`${root}/wt-old`,
			30,
		);
		assertEquals(fromInside.stale, []);
		assertEquals(fromInside.active, 3);

		// A worktree whose directory already vanished is prunable metadata,
		// not a removal candidate.
		await Deno.remove(`${root}/wt-old`, { recursive: true });
		const afterRm = await findStaleWorktrees(discovered, root, 30);
		assertEquals(afterRm.stale, []);
		assertEquals(afterRm.prunable, [repo]);
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});

Deno.test("removeWorktree removes clean trees and forces dirty ones on demand", async () => {
	const root = await Deno.realPath(
		await Deno.makeTempDir({ prefix: "worktrees-rm-" }),
	);
	try {
		const repo = `${root}/repo`;
		await initRepo(repo, old);
		await addWorktree(repo, `${root}/wt-clean`, "feat/clean", old);
		ageDirAndContents(`${root}/wt-clean`);
		await addWorktree(repo, `${root}/wt-dirty`, "feat/dirty", old);
		await Deno.writeTextFile(`${root}/wt-dirty/scratch.txt`, "wip");
		// The scratch file ages with the checkout, so the tree is stale yet
		// still dirty — exactly the --force gate's input.
		ageDirAndContents(`${root}/wt-dirty`);

		const clean = (await findStaleWorktrees(
			await discoverWorktrees(root),
			root,
			30,
		)).stale.find((wt) => wt.path === `${root}/wt-clean`)!;
		assertEquals(await removeWorktree(clean, false), true);
		assertEquals(await pathExists(`${root}/wt-clean`), false);

		// Git refuses to remove a dirty worktree without --force.
		const dirty = (await findStaleWorktrees(
			await discoverWorktrees(root),
			root,
			30,
		)).stale.find((wt) => wt.path === `${root}/wt-dirty`)!;
		assertEquals(await removeWorktree(dirty, false), false);
		assertEquals(await pathExists(`${root}/wt-dirty`), true);
		assertEquals(await removeWorktree(dirty, true), true);
		assertEquals(await pathExists(`${root}/wt-dirty`), false);

		const list = await git(repo, ["worktree", "list", "--porcelain"]);
		assertEquals(list.includes("wt-clean"), false);
		assertEquals(list.includes("wt-dirty"), false);
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});

Deno.test("locked worktrees are flagged so deletion can be skipped", async () => {
	const root = await Deno.realPath(
		await Deno.makeTempDir({ prefix: "worktrees-lock-" }),
	);
	try {
		const repo = `${root}/repo`;
		await initRepo(repo, old);
		await addWorktree(repo, `${root}/wt-locked`, "feat/locked", old);
		ageDirAndContents(`${root}/wt-locked`);
		await git(repo, ["worktree", "lock", `${root}/wt-locked`]);

		const stale = (await findStaleWorktrees(
			await discoverWorktrees(root),
			root,
			30,
		)).stale;
		assertEquals(stale.map((wt) => wt.path), [`${root}/wt-locked`]);
		assertEquals(stale[0].locked, true);
	} finally {
		await Deno.remove(root, { recursive: true });
	}
});
