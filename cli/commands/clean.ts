/**
 * `dotfiles clean` — reclaim disk space
 *
 * Deletes stale AI session transcripts, regenerable caches, Rust target
 * directories, and runs store garbage collection (nh). Dry-run by default;
 * pass --apply to delete.
 *
 * `--when-low <GB>` gates the whole run on free disk space so a scheduler
 * (launchd agent / systemd timer) can call `clean --apply --auto --when-low`
 * periodically without doing work while the disk still has room.
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
const GIBIBYTE = 1024 * 1024 * 1024;

interface CleanOptions {
	apply?: boolean;
	days?: number;
	only?: string[];
	/** Monitor mode: conservative defaults, no Trash emptying. */
	auto?: boolean;
	/** Only run when fewer than this many GiB are free (launchd/systemd). */
	whenLow?: number;
	/** Keep cargo target dirs of projects compiled within the last N days. */
	cargoKeepDays?: number;
}

interface Target {
	label: string;
	path: string;
	/** Estimate the size from one sample dir instead of walking every file. */
	estimate?: boolean;
}

export function fmtBytes(bytes: number): string {
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

/** Parse the "Available" 1K-blocks column of `df -k` output. */
export function parseDfAvailableKilobytes(stdout: string): number | null {
	const lines = stdout.trim().split("\n");
	if (lines.length < 2) return null;
	const columns = lines[lines.length - 1].trim().split(/\s+/);
	// Both macOS and Linux `df -k` put Available in the 4th column.
	const kb = Number.parseInt(columns[3], 10);
	return Number.isFinite(kb) ? kb * 1024 : null;
}

/** Bytes still available on the volume containing `path`, or null. */
export async function freeBytes(path = "/"): Promise<number | null> {
	const { success, stdout } = await runCommand(["df", "-k", path], {
		stdout: "piped",
	});
	if (!success || !stdout) return null;
	return parseDfAvailableKilobytes(stdout);
}

/**
 * Build the `cargo-clean-all` invocation. The tool deletes every `target/`
 * directory under a root; `--yes` skips its confirmation prompt, `--keep-days`
 * protects projects that were built recently, and `--skip` avoids scanning
 * macOS system/app dirs that never contain source projects.
 */
export function cargoCleanAllArgs(keepDays: number, home: string): string[] {
	const args = ["cargo-clean-all", "--yes"];
	if (keepDays > 0) args.push("--keep-days", String(keepDays));
	for (
		const dir of [
			`${home}/Library`,
			`${home}/Downloads`,
			`${home}/.Trash`,
		]
	) {
		args.push("--skip", dir);
	}
	args.push(home);
	return args;
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
	{ label: "deno cache", path: `${HOME}/.cache/deno` },
	{
		label: "deno cache (macOS)",
		path: `${HOME}/Library/Caches/deno`,
	},
	{ label: "gradle caches", path: `${HOME}/.gradle/caches` },
	{ label: "flutter pub cache", path: `${HOME}/.pub-cache` },
	{ label: "dart analysis cache", path: `${HOME}/.dartServer` },
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

	// The pnpm store is a pure content-addressable cache: existing node_modules
	// keep working after deletion because packages are hard-linked into them.
	// `pnpm store path` points at the current versioned store (…/store/v11);
	// its parent also holds older vN stores left by pnpm upgrades that
	// `pnpm store prune` never cleans — on a single machine those were tens of
	// GB, so remove the whole store root.
	if (await commandExists("pnpm")) {
		const storePath = await pnpmStorePath();
		if (storePath) {
			const storeRoot = storePath.replace(/\/v\d+$/, "");
			let bytes = await duBytes(storeRoot);
			if (bytes !== null && bytes > 0) {
				if (apply) {
					try {
						await Deno.remove(storeRoot, { recursive: true });
						printInfo(`pnpm store: removed ${fmtBytes(bytes)}`);
					} catch (error) {
						printError(`Failed to remove pnpm store: ${error}`);
						bytes = 0;
					}
				} else {
					printInfo(`pnpm store (${storeRoot}): ${fmtBytes(bytes)}`);
				}
				freed += bytes;
			}
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

/** `pnpm store path` — the content-addressable package cache location. */
async function pnpmStorePath(): Promise<string | null> {
	const { success, stdout } = await runCommand(["pnpm", "store", "path"], {
		stdout: "piped",
	});
	if (!success || !stdout) return null;
	const path = stdout.trim().split("\n").pop()?.trim();
	return path || null;
}

/**
 * Delete Rust `target/` directories across the home directory with
 * `cargo-clean-all`. The standalone binary is invoked directly so this keeps
 * working even when the rustup `cargo` shim is broken.
 */
async function cleanCargoTargets(
	apply: boolean,
	keepDays: number,
): Promise<number> {
	if (!(await commandExists("cargo-clean-all"))) {
		printWarning(
			"cargo-clean-all not found; skipping Rust target directory cleanup",
		);
		return 0;
	}

	const note = keepDays > 0
		? `keeping projects built in the last ${keepDays} days`
		: "all projects";
	if (!apply) {
		const args = cargoCleanAllArgs(keepDays, HOME).map((arg) =>
			arg === "--yes" ? "--dry-run" : arg
		);
		printInfo(`Rust target directories (${note}); previewing:`);
		await runCommand(args);
		return 0;
	}

	printInfo(`Rust target directories (${note}):`);
	const { success } = await runCommand(cargoCleanAllArgs(keepDays, HOME));
	if (!success) {
		printError("cargo-clean-all failed; see output above");
		return 0;
	}
	printSuccess("Rust target directories cleaned");
	return 0;
}

async function cleanNix(apply: boolean): Promise<number> {
	if (!(await commandExists("nix-collect-garbage"))) {
		printWarning(
			"nix-collect-garbage not found; skipping nix garbage collection",
		);
		return 0;
	}

	// `nh clean user` never needs elevation (unlike `nh clean all`, which wants
	// sudo for the system profile and hangs when there is no TTY). It covers the
	// user profiles, direnv gcroots, and a full store GC, so it is a superset of
	// the old `nix-collect-garbage -d`.
	if (await commandExists("nh")) {
		if (apply) {
			printInfo(
				"Running `nh clean user` (old generations, gcroots, store GC)…",
			);
			const { success } = await runCommand(["nh", "clean", "user"]);
			if (success) {
				printSuccess("Nix user profiles and store garbage collected");
			} else {
				printError("nh clean user failed; see output above");
			}
			// Opportunistic: also clean system generations when sudo happens to be
			// cached (e.g. right after a rebuild). Fails silently otherwise.
			const system = await runCommand(["sudo", "-n", "nh", "clean", "all"]);
			if (system.success) {
				printSuccess("Nix system profiles garbage collected");
			} else {
				printInfo(
					"System profiles not cleaned (sudo credentials not cached) — run `sudo nh clean all` after a rebuild to reclaim those too",
				);
			}
		} else {
			printInfo("Running `nh clean user --dry`:");
			await runCommand(["nh", "clean", "user", "--dry"]);
			printInfo(
				"System profiles: `sudo nh clean all` when sudo is available",
			);
		}
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
			"~/Downloads — installers, archives, torrents",
			"`dust -d 1 ~/Downloads`, delete what you no longer need",
		],
		[
			"~/.tart + ~/Parallels — macOS/Linux VM disk images (often 30–100 GB each)",
			"`tart list` → `tart delete <name>`; remove unused VMs from the Parallels Control Center",
		],
		[
			"~/fvm — Flutter SDK versions",
			"`fvm list`, then `fvm remove <version>` for releases you no longer target",
		],
		[
			"~/.local/share/containers — podman machine VM disks",
			"`podman machine list`, then remove unused machines/images (`podman system prune`)",
		],
		[
			"~/.android/avd — emulator images",
			"`avdmanager delete avd -n <name>` for unused devices",
		],
		[
			"~/Library/Application Support/MobileSync/Backup — iPhone/iPad backups",
			"delete old device backups in Finder → Devices or Settings → General → Storage",
		],
		[
			"~/.ollama — downloaded models",
			"`ollama list`, then `ollama rm <model>`",
		],
		[
			"~/Library/Android/sdk — SDK + emulator system images",
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
			"~/Developer — build artifacts (target, node_modules, dist, .next)",
			"`dot clean --only cargo --apply` handles target/; remove node_modules per project and reinstall when needed",
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
		"Reclaim disk space: stale AI session transcripts, regenerable caches, Rust target dirs, nix GC. Dry-run by default.",
	)
	.option("--apply", "Actually delete files (default is a dry-run report)")
	.option(
		"--days <days:number>",
		"Age threshold in days for session transcripts",
		{ default: 30 },
	)
	.option(
		"--only <category:string>",
		"Limit to a category: sessions, caches, cargo, nix, rustup, trash (repeatable)",
		{ collect: true },
	)
	.option(
		"--auto",
		"Monitor mode: keep cargo targets built today and never touch the Trash (used by the launchd/systemd scheduler)",
	)
	.option(
		"--when-low <gib:number>",
		"Only run when fewer than this many GiB are free (exit early otherwise)",
	)
	.option(
		"--cargo-keep-days <days:number>",
		"Keep cargo target dirs of projects built within the last N days (0 = clean all; --auto defaults to 1)",
	)
	.action(async (options: CleanOptions) => {
		const apply = options.apply ?? false;
		const days = options.days ?? 30;
		const auto = options.auto ?? false;
		const cargoKeepDays = options.cargoKeepDays ??
			(auto ? 1 : 0);
		const only = new Set(options.only ?? []);
		const wants = (category: string) => only.size === 0 || only.has(category);
		// Auto mode skips the Trash unless it is the explicitly requested
		// category — an unattended scheduler must not empty the user's Trash.
		const wantsTrash = wants("trash") &&
			(only.has("trash") || !auto);

		printHeader(
			`Cleaning disk space${
				apply ? "" : " (dry run — pass --apply to delete)"
			}${auto ? " [auto]" : ""}`,
		);

		const free = await freeBytes();
		if (free !== null) printInfo(`Disk space free: ${fmtBytes(free)}`);
		if (options.whenLow !== undefined) {
			if (free === null) {
				printWarning("Could not determine free space; ignoring --when-low");
			} else if (free >= options.whenLow * GIBIBYTE) {
				printSuccess(
					`${
						fmtBytes(free)
					} free is at or above the ${options.whenLow} GB threshold — nothing to do`,
				);
				return;
			} else {
				printWarning(
					`${
						fmtBytes(free)
					} free is below the ${options.whenLow} GB threshold — cleaning`,
				);
			}
		}

		let freed = 0;
		if (wants("sessions")) {
			printInfo(`AI session history older than ${days} days:`);
			freed += await cleanSessions(days, apply);
		}
		if (wants("caches")) {
			printInfo("Regenerable caches:");
			freed += await cleanCaches(apply);
		}
		if (wants("cargo")) {
			freed += await cleanCargoTargets(apply, cargoKeepDays);
		}
		if (wants("nix")) {
			freed += await cleanNix(apply);
		}
		if (wants("rustup")) {
			printInfo("Rust toolchains (keeping stable + newest nightly):");
			freed += await cleanRustup(apply);
		}
		if (wantsTrash) {
			freed += await cleanTrash(apply);
		}

		if (!apply) printManualReviewTargets();
		printSummary(freed, apply);

		if (apply) {
			const after = await freeBytes();
			if (free !== null && after !== null) {
				printInfo(
					`Free space: ${fmtBytes(free)} → ${fmtBytes(after)}`,
				);
			}
		}
	});
