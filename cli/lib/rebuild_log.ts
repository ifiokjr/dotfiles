/**
 * Rebuild log — every `dot rebuild` appends its full stdout and stderr to a
 * per-machine log file, success or failure, so rebuild warnings and errors
 * can be diagnosed after the fact.
 *
 * The rebuild action re-executes itself inside a `bash -c` pipeline that
 * merges stderr into stdout and tees everything into the log, so the log and
 * the terminal stay identical without touching any print helper or command
 * runner. Sessions are delimited by header and footer lines, and the log is
 * capped by trimming its oldest lines once it grows past the size limit.
 *
 * The default log path, `~/.local/state/dotfiles/rebuild.log`, is the same
 * file the launchd fleet flow redirects stdout and stderr into, so unattended
 * and interactive rebuilds share one history.
 */

import { ensureDir, exists } from "@std/fs";
import { basename, dirname, fromFileUrl, join } from "@std/path";
import { printError, printWarning, shellQuote } from "./config.ts";

/** Env marker set on the logged child so it does not re-wrap itself. */
export const REBUILD_LOG_ENV = "DOT_REBUILD_LOG_ACTIVE";

/** Hard cap for the rebuild log. */
export const REBUILD_LOG_MAX_BYTES = 10 * 1024 * 1024;

/**
 * Tail size kept after a trim. Trimming to just under the cap would hit the
 * cap again on the next run and rewrite the file every time; keeping a
 * smaller tail amortizes the rewrite across several rebuilds.
 */
export const REBUILD_LOG_KEEP_BYTES = 8 * 1024 * 1024;

/** Absolute path of the rebuild log inside a home directory. */
export function rebuildLogPath(home = Deno.env.get("HOME") ?? ""): string {
	return join(home, ".local/state/dotfiles/rebuild.log");
}

/**
 * Cap the log at `maxBytes` by dropping its oldest content, keeping roughly
 * the last `keepBytes` rounded down to a line boundary, so the log never
 * starts mid-line and the cut never splits a multibyte UTF-8 character (a
 * newline byte never occurs inside one). Returns true when the log was
 * rewritten.
 */
export async function trimRebuildLog(
	logPath: string,
	maxBytes = REBUILD_LOG_MAX_BYTES,
	keepBytes = REBUILD_LOG_KEEP_BYTES,
): Promise<boolean> {
	const stat = await Deno.stat(logPath).catch(() => null);
	if (!stat?.isFile || stat.size <= maxBytes) return false;

	const tail = await readTail(logPath, stat.size - keepBytes);
	const newline = tail.indexOf(0x0a);
	const kept = newline === -1 ? new Uint8Array(0) : tail.subarray(newline + 1);

	// Rewrite through a temp file so a crash mid-trim leaves the previous log
	// intact instead of a half-written one.
	const tempPath = `${logPath}.${crypto.randomUUID()}.tmp`;
	await Deno.writeFile(tempPath, kept, { mode: 0o600 });
	await Deno.rename(tempPath, logPath);
	return true;
}

/** Read the log from `from` bytes to the end of the file. */
async function readTail(logPath: string, from: number): Promise<Uint8Array> {
	const file = await Deno.open(logPath, { read: true });
	try {
		await file.seek(from, Deno.SeekMode.Start);
		const chunks: Uint8Array[] = [];
		let total = 0;
		// Reads may return fewer bytes than requested, so loop until EOF.
		while (true) {
			const buffer = new Uint8Array(64 * 1024);
			const read = await file.read(buffer);
			if (read === null) break;
			chunks.push(buffer.subarray(0, read));
			total += read;
		}

		const tail = new Uint8Array(total);
		let offset = 0;
		for (const chunk of chunks) {
			tail.set(chunk, offset);
			offset += chunk.length;
		}
		return tail;
	} finally {
		file.close();
	}
}

/** Append the header line that marks the start of one rebuild session. */
export async function writeRebuildLogHeader(
	logPath: string,
	args: string[],
): Promise<void> {
	const line =
		`\n=== dot ${args.join(" ")} — ${new Date().toISOString()} (pid ${Deno.pid}) ===\n`;
	// The leading newline keeps the header on its own line even when the
	// previous run was killed mid-output.
	await Deno.writeTextFile(logPath, line, {
		append: true,
		create: true,
		mode: 0o600,
	});
}

/** Append the footer line recording how one rebuild session ended. */
export async function writeRebuildLogFooter(
	logPath: string,
	code: number,
	startedAtMs: number,
): Promise<void> {
	const line =
		`\n=== exit ${code} — ${new Date().toISOString()} (${
			formatDuration(Date.now() - startedAtMs)
		}) ===\n`;
	await Deno.writeTextFile(logPath, line, { append: true });
}

/** Format a duration as "42s", "3m 05s", or "1h 02m 03s". */
export function formatDuration(ms: number): string {
	const totalSeconds = Math.max(0, Math.round(ms / 1000));
	const seconds = totalSeconds % 60;
	const minutes = Math.floor(totalSeconds / 60) % 60;
	const hours = Math.floor(totalSeconds / 3600);
	if (hours > 0) {
		return `${hours}h ${pad2(minutes)}m ${pad2(seconds)}s`;
	}
	if (minutes > 0) return `${minutes}m ${pad2(seconds)}s`;
	return `${seconds}s`;
}

function pad2(value: number): string {
	return String(value).padStart(2, "0");
}

/** How to re-invoke this CLI for the logged run. */
export interface RebuildExecSpec {
	command: string;
	args: string[];
}

/**
 * Resolve how to re-invoke this CLI with the same rebuild invocation.
 *
 * Compiled binaries (the installed `dotfiles`) re-exec themselves with the
 * same arguments. Source runs (`deno task run`/`dev`) re-invoke the Deno
 * interpreter on the entry module with full permissions, because the
 * original invocation's flags cannot be recovered from inside the process.
 * The interpreter is recognized by its binary name; the compiled CLI is
 * always named `dotfiles` (see the compile task in cli/deno.json).
 */
export async function rebuildExecSpec(
	mainModule: string,
	execPath: string,
	args: string[],
): Promise<RebuildExecSpec> {
	if (basename(execPath) !== "deno") {
		return { command: execPath, args: [...args] };
	}

	const mainPath = mainModule.startsWith("file://")
		? fromFileUrl(mainModule)
		: mainModule;
	// Source runs can start from any cwd, so pin the config that carries the
	// import map instead of relying on Deno's cwd-based discovery.
	const configPath = join(dirname(mainPath), "deno.json");
	return {
		command: execPath,
		args: [
			"run",
			"--allow-all",
			...(await exists(configPath, { isFile: true }))
				? ["--config", configPath]
				: [],
			mainPath,
			...args,
		],
	};
}

/**
 * The bash pipeline that runs the rebuild inside the log: stderr merges into
 * stdout, everything appends to the log, the terminal still sees the live
 * output, and pipefail preserves the rebuild's exit code.
 */
export function loggedRebuildPipeline(
	exec: RebuildExecSpec,
	logPath: string,
): string {
	const command = [exec.command, ...exec.args].map(shellQuote).join(" ");
	return `set -o pipefail; ${command} 2>&1 | tee -a -- ${shellQuote(logPath)}`;
}

/** Options for `runLoggedRebuild`, overridable for tests. */
export interface LoggedRebuildOptions {
	exec?: RebuildExecSpec;
	/** The user-facing arguments recorded in the session header. */
	sessionArgs?: string[];
	logPath?: string;
	/**
	 * Force inherited stdio instead of the tee pipeline. The launchd flow is
	 * detected automatically; this override is for callers that already know
	 * their output is captured, and for tests.
	 */
	inheritStdio?: boolean;
}

/**
 * Run this rebuild with all of its output appended to the rebuild log.
 *
 * # Why The Re-Exec
 *
 * Rebuild output comes from two places that cannot be intercepted in-process
 * at the same time: the CLI's own prints and child processes that inherit the
 * terminal file descriptors. Re-running the same invocation as a child of a
 * tee pipeline captures both at the fd level with a single mechanism, and
 * keeps the terminal output identical to the log.
 *
 * Returns the exit code the caller should exit with, or null to continue
 * unwrapped: when the current process is already the logged child, or when
 * the log cannot be set up (logging never blocks a rebuild).
 */
export async function runLoggedRebuild(
	options: LoggedRebuildOptions = {},
): Promise<number | null> {
	if (Deno.env.get(REBUILD_LOG_ENV)) return null;

	const logPath = options.logPath ?? rebuildLogPath();
	const exec = options.exec ??
		await rebuildExecSpec(Deno.mainModule, Deno.execPath(), Deno.args);

	try {
		await ensureDir(dirname(logPath));
		await trimRebuildLog(logPath);
		await writeRebuildLogHeader(
			logPath,
			options.sessionArgs ?? [...Deno.args],
		);
	} catch (error) {
		printWarning(
			`Rebuild log unavailable at ${logPath} (${errorMessage(error)}); continuing without logging`,
		);
		return null;
	}

	console.log(`Logging rebuild output to ${logPath}`);
	const startedAtMs = Date.now();

	let code: number;
	try {
		code = await spawnLogged(exec, logPath, options.inheritStdio === true);
	} catch (error) {
		printError(`Failed to start the rebuild: ${errorMessage(error)}`);
		return 1;
	}

	try {
		await writeRebuildLogFooter(logPath, code, startedAtMs);
		await trimRebuildLog(logPath);
	} catch {
		// The rebuild finished; a failed bookkeeping write must not turn into a
		// failed rebuild.
	}
	return code;
}

/**
 * Spawn the rebuild through the logging pipeline, or with inherited fds when
 * stdout already points at the log file itself.
 */
async function spawnLogged(
	exec: RebuildExecSpec,
	logPath: string,
	inheritStdio: boolean,
): Promise<number> {
	if (inheritStdio || await stdoutPointsAt(logPath)) {
		// The launchd fleet flow redirects stdout and stderr into this same log
		// file. Piping through tee would then write every line twice, so let
		// the rebuild inherit the redirect as-is; it is already logged.
		return runInherit(exec);
	}

	const child = new Deno.Command("bash", {
		args: ["-c", loggedRebuildPipeline(exec, logPath)],
		env: { ...Deno.env.toObject(), [REBUILD_LOG_ENV]: "1" },
		stdin: "inherit",
		stdout: "inherit",
		stderr: "inherit",
	}).spawn();
	return (await child.status).code;
}

/** Run the rebuild with inherited stdio and the logged-child env marker. */
async function runInherit(exec: RebuildExecSpec): Promise<number> {
	const child = new Deno.Command(exec.command, {
		args: exec.args,
		env: { ...Deno.env.toObject(), [REBUILD_LOG_ENV]: "1" },
		stdin: "inherit",
		stdout: "inherit",
		stderr: "inherit",
	}).spawn();
	return (await child.status).code;
}

/**
 * Whether the process's stdout is the log file itself, detected by inode:
 * stat'ing /dev/stdout resolves the file fd 1 points at. `dev` is unreliable
 * here because Deno reports it through an f64 that mangles large values.
 */
export async function stdoutPointsAt(logPath: string): Promise<boolean> {
	try {
		const [stdout, log] = await Promise.all([
			Deno.stat("/dev/stdout"),
			Deno.stat(logPath),
		]);
		return stdout.isFile && log.isFile && stdout.ino === log.ino;
	} catch {
		return false;
	}
}

function errorMessage(error: unknown): string {
	return error instanceof Error ? error.message : String(error);
}
