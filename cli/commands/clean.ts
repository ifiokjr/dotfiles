/**
 * `dotfiles clean` — reclaim disk space
 *
 * Deletes stale AI session transcripts, regenerable caches, and runs store
 * garbage collection. Dry-run by default; pass --apply to delete.
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

const HOME = Deno.env.get("HOME") ?? "/tmp";

interface CleanOptions {
	apply?: boolean;
	days?: number;
	only?: string[];
}

interface Target {
	label: string;
	path: string;
	/** Estimate the size from one sample dir instead of walking every file. */
	estimate?: boolean;
}

function fmtBytes(bytes: number): string {
	if (bytes < 1024) return `${bytes} B`;
	const units = ["KB", "MB", "GB", "TB"];
	let value = bytes / 1024;
	let unit = 0;
	while (value >= 1024 && unit < units.length - 1) {
		value /= 1024;
		unit++;
	}
	return `${value.toFixed(value >= 10 ? 0 : 1)} ${units[unit]}`;
}

/** du -sk, returning bytes or null when the path is missing. */
async function duBytes(path: string): Promise<number | null> {
	const { success, stdout } = await runCommand(["du", "-sk", path], {
		stdout: "piped",
	});
	if (!success || !stdout) return null;
	const kb = Number.parseInt(stdout.split("\t")[0], 10);
	return Number.isFinite(kb) ? kb * 1024 : null;
}

/** Recursively collect regular files older than cutoff, skipping symlinks. */
async function collectOldFiles(
	root: string,
	cutoffMs: number,
): Promise<{ files: string[]; bytes: number }> {
	const files: string[] = [];
	let bytes = 0;

	async function visit(dir: string): Promise<void> {
		let entries: AsyncIterable<Deno.DirEntry>;
		try {
			entries = Deno.readDir(dir);
		} catch {
			return;
		}
		for await (const entry of entries) {
			if (entry.isSymlink) continue;
			const path = `${dir}/${entry.name}`;
			if (entry.isDirectory) {
				await visit(path);
				continue;
			}
			if (!entry.isFile) continue;
			try {
				const st = await Deno.lstat(path);
				if (st.mtime && st.mtime.getTime() < cutoffMs) {
					files.push(path);
					bytes += st.size;
				}
			} catch {
				// File vanished mid-walk; ignore.
			}
		}
	}

	try {
		await visit(root);
	} catch {
		// Root missing; nothing to collect.
	}
	return { files, bytes };
}

/** Top-level dirs under `root` whose own mtime is older than cutoff. */
async function collectOldDirs(
	root: string,
	cutoffMs: number,
): Promise<string[]> {
	const dirs: string[] = [];
	try {
		for await (const entry of Deno.readDir(root)) {
			if (!entry.isDirectory || entry.isSymlink) continue;
			const path = `${root}/${entry.name}`;
			try {
				const st = await Deno.lstat(path);
				if (st.mtime && st.mtime.getTime() < cutoffMs) dirs.push(path);
			} catch {
				// Ignore entries that vanish mid-scan.
			}
		}
	} catch {
		// Root missing.
	}
	return dirs;
}

/** macOS per-user temp dir with the trailing /T segment stripped. */
async function darwinUserBase(): Promise<string | null> {
	if (Deno.build.os !== "darwin") return null;
	const { success, stdout } = await runCommand(
		["getconf", "DARWIN_USER_TEMP_DIR"],
		{ stdout: "piped" },
	);
	if (!success || !stdout) return null;
	return stdout.trim().replace(/\/T\/$/, "") || null;
}

/** Chrome code-sign clones macOS accumulates under the user's var/folders. */
async function chromeCloneDir(): Promise<string | null> {
	const base = await darwinUserBase();
	return base ? `${base}/X/com.google.Chrome.code_sign_clone` : null;
}

/** Extract a dated nightly's date string, e.g. `2026-09-05`. */
const nightlyDate = (name: string) => name.match(/\d{4}-\d{2}-\d{2}/);

const cacheTargets = (): Target[] => [
	{
		label: "Xcode DerivedData",
		path: `${HOME}/Library/Developer/Xcode/DerivedData`,
	},
	{
		label: "Xcode iOS DeviceSupport",
		path: `${HOME}/Library/Developer/Xcode/iOS DeviceSupport`,
	},
	{
		label: "Simulator caches",
		path: `${HOME}/Library/Developer/CoreSimulator/Caches`,
	},
	{ label: "npm cache", path: `${HOME}/.npm/_cacache` },
	{ label: "cargo registry", path: `${HOME}/.cargo/registry` },
	{ label: "uv cache", path: `${HOME}/.cache/uv` },
	{ label: "puppeteer browsers", path: `${HOME}/.cache/puppeteer` },
	{
		label: "Playwright browsers",
		path: `${HOME}/Library/Caches/ms-playwright`,
	},
	{ label: "Solana build cache", path: `${HOME}/.cache/solana` },
	{ label: "Nix fetch cache", path: `${HOME}/.cache/nix` },
	{ label: "gh clone cache", path: `${HOME}/.cache/gh` },
	{ label: "Codex runtimes cache", path: `${HOME}/.cache/codex-runtimes` },
];

async function cleanSessions(
	days: number,
	apply: boolean,
): Promise<number> {
	const cutoffMs = Date.now() - days * 24 * 60 * 60 * 1000;
	const roots: Target[] = [
		{ label: "Codex sessions", path: `${HOME}/.codex/sessions` },
		{
			label: "Codex archived sessions",
			path: `${HOME}/.codex/archived_sessions`,
		},
		{ label: "Pi sessions", path: `${HOME}/.pi/agent/sessions` },
		{
			label: "OpenCode messages",
			path: `${HOME}/.local/share/opencode/storage`,
		},
	];

	let freed = 0;
	for (const root of roots) {
		const { files, bytes } = await collectOldFiles(root.path, cutoffMs);
		if (files.length === 0) continue;
		if (apply) {
			let removed = 0;
			for (const file of files) {
				try {
					await Deno.remove(file);
					removed++;
				} catch {
					// Already gone or locked; keep going.
				}
			}
			printInfo(
				`${root.label}: deleted ${removed} files (≈${fmtBytes(bytes)})`,
			);
		} else {
			printInfo(
				`${root.label}: ${files.length} files, ${
					fmtBytes(bytes)
				} older than ${days}d`,
			);
		}
		freed += bytes;
	}

	const worktreeRoot = `${HOME}/.pi/agent/worktrees`;
	const staleWorktrees = await collectOldDirs(worktreeRoot, cutoffMs);
	if (staleWorktrees.length > 0) {
		let bytes = 0;
		for (const dir of staleWorktrees) {
			const size = await duBytes(dir);
			bytes += size ?? 0;
		}
		if (apply) {
			for (const dir of staleWorktrees) {
				try {
					await Deno.remove(dir, { recursive: true });
				} catch {
					// Ignore; report the total either way.
				}
			}
			printInfo(
				`Pi session worktrees: deleted ${staleWorktrees.length} dirs (≈${
					fmtBytes(bytes)
				})`,
			);
		} else {
			printInfo(
				`Pi session worktrees: ${staleWorktrees.length} stale dirs, ${
					fmtBytes(bytes)
				}`,
			);
		}
		freed += bytes;
	}

	return freed;
}

async function cleanCaches(apply: boolean): Promise<number> {
	let freed = 0;

	const clonesDir = await chromeCloneDir();
	if (clonesDir) {
		const entries: string[] = [];
		try {
			for await (const entry of Deno.readDir(clonesDir)) {
				entries.push(entry.name);
			}
		} catch {
			// No clones; nothing to do.
		}
		if (entries.length > 0) {
			const sample = await duBytes(`${clonesDir}/${entries[0]}`);
			const estimated = (sample ?? 0) * entries.length;
			const note = `≈${
				fmtBytes(estimated)
			} (${entries.length} clones; quit Chrome first)`;
			if (apply) {
				try {
					await Deno.remove(clonesDir, { recursive: true });
					printInfo(`Chrome code-sign clones: removed ${note}`);
				} catch (error) {
					printError(`Failed to remove Chrome code-sign clones: ${error}`);
				}
			} else {
				printInfo(`Chrome code-sign clones: ${note}`);
			}
			freed += estimated;
		}
	}

	for (const target of cacheTargets()) {
		const bytes = await duBytes(target.path);
		if (bytes === null || bytes === 0) continue;
		if (apply) {
			try {
				await Deno.remove(target.path, { recursive: true });
				printInfo(`${target.label}: removed ${fmtBytes(bytes)}`);
			} catch (error) {
				printError(`Failed to remove ${target.label}: ${error}`);
				continue;
			}
		} else {
			printInfo(`${target.label}: ${fmtBytes(bytes)}`);
		}
		freed += bytes;
	}

	if (await commandExists("pnpm")) {
		if (apply) {
			printInfo("Running `pnpm store prune` (removes unreferenced packages)…");
			const { success } = await runCommand(["pnpm", "store", "prune"]);
			if (success) printSuccess("pnpm store pruned");
		} else {
			printInfo("pnpm store: prune on --apply (unreferenced packages)");
		}
	}

	if (Deno.build.os === "darwin" && (await commandExists("xcrun"))) {
		if (apply) {
			printInfo("Running `xcrun simctl delete unavailable`…");
			const { success } = await runCommand([
				"xcrun",
				"simctl",
				"delete",
				"unavailable",
			]);
			if (success) printSuccess("Unavailable simulators deleted");
		} else {
			printInfo("Simulators: `xcrun simctl delete unavailable` on --apply");
		}
	}

	return freed;
}

async function cleanNix(apply: boolean): Promise<number> {
	if (!(await commandExists("nix-collect-garbage"))) {
		printWarning(
			"nix-collect-garbage not found; skipping nix garbage collection",
		);
		return 0;
	}
	if (apply) {
		printInfo(
			"Running `nix-collect-garbage -d` (old generations + unreferenced store paths)…",
		);
		const { success } = await runCommand(["nix-collect-garbage", "-d"]);
		if (success) printSuccess("Nix store garbage collected");
		return 0;
	}
	printInfo("Nix store: `nix-collect-garbage -d` on --apply");
	return 0;
}

async function cleanTrash(apply: boolean): Promise<number> {
	const trash = `${HOME}/.Trash`;
	let bytes = 0;
	try {
		for await (const entry of Deno.readDir(trash)) {
			const path = `${trash}/${entry.name}`;
			bytes += (await duBytes(path)) ?? 0;
		}
	} catch {
		return 0;
	}
	if (bytes === 0) return 0;
	if (apply) {
		try {
			for await (const entry of Deno.readDir(trash)) {
				await Deno.remove(`${trash}/${entry.name}`, { recursive: true });
			}
			printInfo(`Trash: emptied ${fmtBytes(bytes)}`);
		} catch (error) {
			printError(`Failed to empty Trash: ${error}`);
			return 0;
		}
	} else {
		printInfo(`Trash: ${fmtBytes(bytes)}`);
	}
	return bytes;
}

/** Uninstall rust toolchains except stable and the newest nightly. */
async function cleanRustup(apply: boolean): Promise<number> {
	const toolchainsDir = `${HOME}/.rustup/toolchains`;
	const names: string[] = [];
	try {
		for await (const entry of Deno.readDir(toolchainsDir)) {
			if (entry.isDirectory) names.push(entry.name);
		}
	} catch {
		return 0;
	}
	if (names.length === 0) return 0;

	// The floating `nightly-<target>` dir is what `rustfmt +nightly` resolves to;
	// keep it plus stable and the newest dated nightly. `.bak-*` dirs are always
	// rustup leftovers and always removable.
	const nightlies = names
		.filter((name) => name.startsWith("nightly-") && nightlyDate(name))
		.toSorted();
	const keep = new Set<string>(
		names.filter(
			(name) =>
				name.startsWith("stable-") ||
				(name.startsWith("nightly-") && !nightlyDate(name)),
		),
	);
	if (nightlies.length > 0) keep.add(nightlies[nightlies.length - 1]);

	const removals = names.filter((name) => !keep.has(name));
	if (removals.length === 0) return 0;

	let bytes = 0;
	for (const name of removals) {
		const size = await duBytes(`${toolchainsDir}/${name}`);
		bytes += size ?? 0;
	}

	if (apply) {
		for (const name of removals) {
			printInfo(`rustup toolchain uninstall ${name}…`);
			const { success } = await runCommand([
				"rustup",
				"toolchain",
				"uninstall",
				name,
			]);
			if (success) {
				printSuccess(`Removed ${name}`);
			} else {
				printError(`Failed to remove ${name}`);
			}
		}
	} else {
		printInfo(
			`${removals.length} old toolchains (keeping stable + ${
				nightlies[nightlies.length - 1] ?? "none"
			}): ${fmtBytes(bytes)}`,
		);
		for (const name of removals) {
			printInfo(`  - ${name}`);
		}
	}
	return bytes;
}

/** Big items that need human judgment; never auto-deleted. */
function printManualReviewTargets(): void {
	printHeader("Also worth reviewing manually (not auto-deleted)");
	const notes: [string, string][] = [
		[
			"~/.ollama — downloaded models",
			"`ollama list`, then `ollama rm <model>`",
		],
		[
			"~/Library/Android/sdk — SDK + emulator images",
			"`sdkmanager --uninstall` unused platforms/system-images",
		],
		[
			"~/Library/Developer/CoreSimulator/Devices",
			"`xcrun simctl delete <udid>` or erase unused device types",
		],
		[
			"~/Library/Application Support/Steam — game files",
			"uninstall unused games in Steam",
		],
		[
			"~/.local/share/containers — container/VM images",
			"`podman system prune` (or the equivalent for your engine)",
		],
		[
			"~/Developer/projects — build artifacts (node_modules, target, dist)",
			"remove per project and reinstall/rebuild when needed",
		],
		[
			"~/.codex/thread_history_1.sqlite + logs_2.sqlite — Codex chat DBs",
			"delete manually only while no Codex session is running",
		],
	];
	for (const [path, hint] of notes) {
		printWarning(`${path} — ${hint}`);
	}
}

function printSummary(freed: number, apply: boolean): void {
	if (apply) {
		printSuccess(`Cleaned ${fmtBytes(freed)} of reclaimable space`);
	} else {
		printInfo(
			`Estimated reclaim: ≈${
				fmtBytes(freed)
			} (dry run — pass --apply to delete)`,
		);
	}
}

export const cleanCommand = new Command()
	.description(
		"Reclaim disk space: stale AI session transcripts, regenerable caches, nix GC. Dry-run by default.",
	)
	.option("--apply", "Actually delete files (default is a dry-run report)")
	.option(
		"--days <days:number>",
		"Age threshold in days for session transcripts",
		{ default: 30 },
	)
	.option(
		"--only <category:string>",
		"Limit to a category: sessions, caches, nix, rustup, trash (repeatable)",
		{ collect: true },
	)
	.action(async (options: CleanOptions) => {
		const apply = options.apply ?? false;
		const days = options.days ?? 30;
		const only = new Set(options.only ?? []);
		const wants = (category: string) => only.size === 0 || only.has(category);

		printHeader(
			`Cleaning disk space${
				apply ? "" : " (dry run — pass --apply to delete)"
			}`,
		);

		let freed = 0;
		if (wants("sessions")) {
			printInfo(`AI session history older than ${days} days:`);
			freed += await cleanSessions(days, apply);
		}
		if (wants("caches")) {
			printInfo("Regenerable caches:");
			freed += await cleanCaches(apply);
		}
		if (wants("nix")) {
			freed += await cleanNix(apply);
		}
		if (wants("rustup")) {
			printInfo("Rust toolchains (keeping stable + newest nightly):");
			freed += await cleanRustup(apply);
		}
		if (wants("trash")) {
			freed += await cleanTrash(apply);
		}

		if (!apply) printManualReviewTargets();
		printSummary(freed, apply);
	});
