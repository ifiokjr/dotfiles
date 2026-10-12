/**
 * `dotfiles worktrees` — reclaim space held by stale git worktrees.
 *
 * Agent and PR workflows create worktrees per task and clean them up when
 * they merge, but abandoned work is common enough that dozens of checkouts
 * (each carrying node_modules and build output) pile up for months. This
 * sweeps every worktree registered by a repo under ~/Developer and removes
 * the ones neither committed nor touched within --days.
 *
 * Staleness uses two signals — last commit AND last source-file change:
 * a worktree taken yesterday from a branch whose tip is months old still
 * reads as touched (checkout rewrites file mtimes), and so does work sitting
 * uncommitted in one. Commit date alone would delete both.
 *
 * Deliberately separate from `dotfiles clean`: a worktree is a whole checkout
 * that can hold uncommitted work, not a regenerable cache, so it gets its own
 * command, its own dry-run, and a --force gate for dirty worktrees.
 *
 * Branches are never touched here — deleting them is a merge-aware decision
 * that the git-workflow skill already handles at PR time.
 */

import { Command } from "@cliffy/command";
import {
	commandExists,
	printError,
	printHeader,
	printInfo,
	printSuccess,
	printWarning,
	runCommand,
} from "../lib/config.ts";
import {
	developerRoot,
	discoverWorktrees,
	duBytes,
	isDirtyWorktree,
	lastCommitMs,
	newestSourceMtime,
	type ParsedWorktree,
	pathExists,
} from "../lib/devscan.ts";
import { fmtBytes } from "./clean.ts";

interface WorktreesOptions {
	apply?: boolean;
	days?: number;
	force?: boolean;
}

/** Worktrees owned by `dotfiles clean --only sessions`, never this command. */
const piWorktreeRoot = () =>
	`${Deno.env.get("HOME") ?? "/tmp"}/.pi/agent/worktrees`;

const isInside = (path: string, dir: string) =>
	path === dir || path.startsWith(`${dir}/`);

/** Whether a worktree must never be removed: it is the repo's main checkout,
 * it is where the user currently stands, it is locked, or it belongs to
 * another tool.
 */
export function isProtectedWorktree(wt: ParsedWorktree, cwd: string): boolean {
	if (wt.path === wt.main) return true;
	if (isInside(cwd, wt.path)) return true;
	if (isProtectedPath(wt.path)) return true;
	return false;
}

/** Paths no removal may touch, regardless of age. */
function isProtectedPath(path: string): boolean {
	return isInside(path, piWorktreeRoot());
}

const touchedDate = (ms: number) => new Date(ms).toISOString().slice(0, 10);

export interface Candidate {
	path: string;
	main: string;
	branch: string | null;
	/** Last commit or source-file change, whichever is newer (ms). */
	lastTouched: number;
	locked: boolean;
	bytes: number;
}

/**
 * Partition every discovered worktree into stale candidates (neither committed
 * nor touched within `days`), active ones, and stale registrations whose
 * directory is already gone (prunable metadata).
 */
export async function findStaleWorktrees(
	worktrees: ParsedWorktree[],
	cwd: string,
	days: number,
): Promise<{ stale: Candidate[]; active: number; prunable: string[] }> {
	const cutoffMs = Date.now() - days * 24 * 60 * 60 * 1000;
	const stale: Candidate[] = [];
	const prunable: string[] = [];
	let active = 0;

	for (const wt of worktrees) {
		if (wt.bare) continue;
		if (isProtectedWorktree(wt, cwd)) continue;
		if (!(await pathExists(wt.path))) {
			if (!prunable.includes(wt.main)) prunable.push(wt.main);
			continue;
		}
		const committed = (await lastCommitMs(wt.path)) ?? 0;
		// Only worktrees with an old last commit need the mtime walk: a recent
		// commit already proves they are touched.
		const touched = committed > cutoffMs
			? committed
			: Math.max(committed, (await newestSourceMtime(wt.path)) ?? 0);
		if (touched > cutoffMs) {
			active++;
			continue;
		}
		stale.push({
			path: wt.path,
			main: wt.main,
			branch: wt.branch,
			lastTouched: touched,
			locked: wt.locked,
			bytes: (await duBytes(wt.path)) ?? 0,
		});
	}
	stale.sort((a, b) => b.bytes - a.bytes);
	return { stale, active, prunable };
}

/** Remove one stale worktree through git so its registration goes with it. */
export async function removeWorktree(
	candidate: Candidate,
	force: boolean,
): Promise<boolean> {
	const args = ["git", "-C", candidate.main, "worktree", "remove"];
	if (force) args.push("--force");
	args.push(candidate.path);
	const { success } = await runCommand(args, { stderr: "null" });
	if (!success) return false;
	await runCommand(["git", "-C", candidate.main, "worktree", "prune"], {
		stderr: "null",
	});
	return true;
}

export const worktreesCommand = new Command()
	.description(
		"Remove stale git worktrees under ~/Developer. Dry-run by default; pass --apply to delete. Branches are left alone.",
	)
	.option("--apply", "Actually delete worktrees (default is a dry-run report)")
	.option(
		"--days <days:number>",
		"Remove worktrees with no commits and no file changes in the last N days",
		{ default: 30 },
	)
	.option(
		"--force",
		"Also delete worktrees that hold uncommitted changes (git worktree remove --force)",
	)
	.action(async (options: WorktreesOptions) => {
		const apply = options.apply ?? false;
		const days = options.days ?? 30;
		const force = options.force ?? false;
		const root = developerRoot();

		printHeader(
			`Stale git worktrees under ~/Developer${
				apply ? "" : " (dry run — pass --apply to delete)"
			}`,
		);

		if (!(await commandExists("git"))) {
			printError("git not found; nothing to do");
			return;
		}
		if (!(await pathExists(root))) {
			printInfo("No ~/Developer; nothing to do");
			return;
		}

		const { stale, active, prunable } = await findStaleWorktrees(
			await discoverWorktrees(root),
			Deno.cwd(),
			days,
		);

		for (const main of prunable) {
			if (apply) {
				await runCommand(["git", "-C", main, "worktree", "prune"], {
					stderr: "null",
				});
				printSuccess(`Pruned stale worktree registrations in ${main}`);
			} else {
				printInfo(
					`Stale worktree registrations in ${main} (pruned on --apply)`,
				);
			}
		}

		if (stale.length === 0) {
			printInfo(`No worktrees untouched for ${days} days`);
			return;
		}

		for (const wt of stale) {
			const when = wt.lastTouched > 0
				? `last touched ${touchedDate(wt.lastTouched)}`
				: "never touched";
			const state = wt.locked ? "locked" : "";
			printInfo(
				`  ${wt.path} — ${fmtBytes(wt.bytes)}, ${when}${
					state ? `, ${state}` : ""
				}${wt.branch ? ` [${wt.branch}]` : ""}`,
			);
		}

		if (!apply) {
			printInfo(
				`${stale.length} stale worktrees, ${
					fmtBytes(stale.reduce((total, wt) => total + wt.bytes, 0))
				} reclaimable${active > 0 ? `; ${active} newer worktrees kept` : ""}`,
			);
			return;
		}

		let freed = 0;
		for (const wt of stale) {
			if (wt.locked) {
				printWarning(`Skipping locked worktree: ${wt.path}`);
				continue;
			}
			const dirty = await isDirtyWorktree(wt.path);
			if (dirty && !force) {
				printWarning(
					`Skipping ${wt.path}: uncommitted changes (re-run with --force to delete)`,
				);
				continue;
			}
			if (await removeWorktree(wt, dirty)) {
				freed += wt.bytes;
				printSuccess(`Removed ${wt.path} (${fmtBytes(wt.bytes)})`);
			} else {
				printError(`Failed to remove ${wt.path}`);
			}
		}
		printSuccess(`Reclaimed ${fmtBytes(freed)} of worktree space`);
	});
