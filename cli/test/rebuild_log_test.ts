import { assertEquals, assertStringIncludes } from "@std/assert";
import { join } from "@std/path";
import {
	formatDuration,
	loggedRebuildPipeline,
	rebuildExecSpec,
	rebuildLogPath,
	REBUILD_LOG_ENV,
	runLoggedRebuild,
	stdoutPointsAt,
	trimRebuildLog,
	writeRebuildLogFooter,
	writeRebuildLogHeader,
} from "../lib/rebuild_log.ts";

async function inTempDir(): Promise<string> {
	return await Deno.makeTempDir({ prefix: "rebuild-log-" });
}

Deno.test("rebuildLogPath lives under the per-machine state directory", () => {
	assertEquals(
		rebuildLogPath("/home/tester"),
		"/home/tester/.local/state/dotfiles/rebuild.log",
	);
});

Deno.test("trimRebuildLog leaves logs at or under the cap alone", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		const content = "line\n".repeat(10);
		await Deno.writeTextFile(logPath, content);
		assertEquals(await trimRebuildLog(logPath, 1000, 500), false);
		assertEquals(await Deno.readTextFile(logPath), content);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("trimRebuildLog is a no-op for a missing log", async () => {
	const dir = await inTempDir();
	try {
		assertEquals(await trimRebuildLog(join(dir, "missing.log"), 10, 5), false);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("trimRebuildLog drops the oldest lines past the cap", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		const lines = Array.from(
			{ length: 20 },
			(_, i) => `line-${String(i).padStart(2, "0")}\n`,
		);
		await Deno.writeTextFile(logPath, lines.join(""));

		assertEquals(await trimRebuildLog(logPath, 40, 40), true);

		const kept = await Deno.readTextFile(logPath);
		assertEquals(kept.length <= 40, true);
		assertEquals(kept.startsWith("line-"), true);
		assertEquals(kept.endsWith("line-19\n"), true);
		assertEquals(kept.includes("line-00"), false);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("trimRebuildLog never splits multibyte characters", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		// 10 emoji (4 bytes each) followed by a newline and a short line: the
		// kept tail starts in the middle of an emoji, and only the line-boundary
		// cut makes the result valid UTF-8.
		await Deno.writeTextFile(logPath, `${"🦕".repeat(10)}\ntail-line\n`);

		assertEquals(await trimRebuildLog(logPath, 20, 20), true);
		assertEquals(await Deno.readTextFile(logPath), "tail-line\n");
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("trimRebuildLog empties a log with no line boundaries", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		await Deno.writeTextFile(logPath, "x".repeat(60));

		assertEquals(await trimRebuildLog(logPath, 20, 20), true);
		assertEquals((await Deno.stat(logPath)).size, 0);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("session markers delimit one rebuild run", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		await writeRebuildLogHeader(logPath, ["rebuild", "--update"]);
		await Deno.writeTextFile(logPath, "rebuild output\n", { append: true });
		await writeRebuildLogFooter(logPath, 3, Date.now() - 65_000);

		const content = await Deno.readTextFile(logPath);
		assertStringIncludes(content, "=== dot rebuild --update — ");
		assertStringIncludes(content, "(pid ");
		assertStringIncludes(content, "rebuild output\n");
		assertStringIncludes(content, "=== exit 3 — ");
		assertStringIncludes(content, "(1m 05s) ===");
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("formatDuration renders seconds, minutes, and hours", () => {
	assertEquals(formatDuration(0), "0s");
	assertEquals(formatDuration(41_500), "42s");
	assertEquals(formatDuration(65_000), "1m 05s");
	assertEquals(formatDuration(3_723_000), "1h 02m 03s");
});

Deno.test("loggedRebuildPipeline pipes the rebuild through tee", () => {
	const pipeline = loggedRebuildPipeline(
		{ command: "/usr/local/bin/dotfiles", args: ["rebuild", "--latest"] },
		"/tmp/state dir/rebuild.log",
	);
	assertStringIncludes(pipeline, "set -o pipefail");
	assertStringIncludes(pipeline, "/usr/local/bin/dotfiles rebuild --latest");
	assertStringIncludes(
		pipeline,
		"2>&1 | tee -a -- '/tmp/state dir/rebuild.log'",
	);
});

Deno.test("rebuildExecSpec re-execs compiled binaries directly", async () => {
	assertEquals(
		await rebuildExecSpec(
			"file:///anywhere/main.ts",
			"/usr/local/bin/dotfiles",
			["rebuild", "--latest"],
		),
		{ command: "/usr/local/bin/dotfiles", args: ["rebuild", "--latest"] },
	);
});

Deno.test("rebuildExecSpec reruns Deno on the entry module for source runs", async () => {
	const dir = await inTempDir();
	try {
		const configPath = join(dir, "deno.json");
		const mainPath = join(dir, "main.ts");
		await Deno.writeTextFile(configPath, "{}");
		await Deno.writeTextFile(mainPath, "");

		assertEquals(
			await rebuildExecSpec(`file://${mainPath}`, "/usr/bin/deno", ["rebuild"]),
			{
				command: "/usr/bin/deno",
				args: ["run", "--allow-all", "--config", configPath, mainPath, "rebuild"],
			},
		);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("rebuildExecSpec omits --config without a deno.json", async () => {
	const dir = await inTempDir();
	try {
		const mainPath = join(dir, "main.ts");
		await Deno.writeTextFile(mainPath, "");

		assertEquals(
			await rebuildExecSpec(`file://${mainPath}`, "/usr/bin/deno", ["rebuild"]),
			{
				command: "/usr/bin/deno",
				args: ["run", "--allow-all", mainPath, "rebuild"],
			},
		);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("runLoggedRebuild captures both streams and the exit code", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		const code = await runLoggedRebuild({
			exec: {
				command: "bash",
				args: ["-c", "echo rebuild-out; echo rebuild-err >&2; exit 0"],
			},
			sessionArgs: ["rebuild", "--update"],
			logPath,
		});

		assertEquals(code, 0);
		const content = await Deno.readTextFile(logPath);
		assertStringIncludes(content, "=== dot rebuild --update — ");
		assertStringIncludes(content, "rebuild-out\n");
		assertStringIncludes(content, "rebuild-err\n");
		assertStringIncludes(content, "=== exit 0 — ");
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("runLoggedRebuild propagates failure exit codes", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		const code = await runLoggedRebuild({
			exec: { command: "bash", args: ["-c", "echo boom >&2; exit 7"] },
			logPath,
		});

		assertEquals(code, 7);
		const content = await Deno.readTextFile(logPath);
		assertStringIncludes(content, "boom\n");
		assertStringIncludes(content, "=== exit 7 — ");
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("runLoggedRebuild is a no-op inside the logged child", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		Deno.env.set(REBUILD_LOG_ENV, "1");
		try {
			assertEquals(
				await runLoggedRebuild({
					exec: { command: "false", args: [] },
					logPath,
				}),
				null,
			);
		} finally {
			Deno.env.delete(REBUILD_LOG_ENV);
		}
		assertEquals(await Deno.stat(logPath).catch(() => null), null);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("runLoggedRebuild continues unwrapped when the log is unwritable", async () => {
	const dir = await inTempDir();
	try {
		// A file where the log's parent directory should be makes ensureDir
		// fail; the rebuild would then run unlogged instead of failing.
		const blocker = join(dir, "blocker");
		await Deno.writeTextFile(blocker, "");

		assertEquals(
			await runLoggedRebuild({
				exec: { command: "false", args: [] },
				logPath: join(blocker, "rebuild.log"),
			}),
			null,
		);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("runLoggedRebuild forces inherited stdio when requested", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		const code = await runLoggedRebuild({
			exec: { command: "/bin/echo", args: ["hello-inherit"] },
			logPath,
			inheritStdio: true,
		});

		assertEquals(code, 0);
		// With inherited stdio the rebuild's stdout is the terminal, so the
		// echo's own output line never lands in the log (only the header's
		// copy of the arguments does).
		const content = await Deno.readTextFile(logPath);
		assertEquals(content.match(/^hello-inherit$/gm), null);
		assertStringIncludes(content, "=== exit 0 — ");
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("runLoggedRebuild reports a clean failure when the rebuild cannot start", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		const code = await runLoggedRebuild({
			exec: { command: "/nonexistent-rebuild-binary", args: [] },
			logPath,
			inheritStdio: true,
		});

		assertEquals(code, 1);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("runLoggedRebuild keeps bookkeeping failures non-fatal", async () => {
	const dir = await inTempDir();
	try {
		const logPath = join(dir, "rebuild.log");
		// The rebuild moves the log away mid-run, so the footer write and the
		// closing trim both fail; the exit code must survive anyway.
		const code = await runLoggedRebuild({
			exec: {
				command: "bash",
				args: ["-c", `echo gone; mv ${logPath} ${logPath}.moved`],
			},
			logPath,
		});

		assertEquals(code, 0);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("stdoutPointsAt is false for anything but the log itself", async () => {
	const dir = await inTempDir();
	try {
		// A missing log cannot match stdout.
		assertEquals(await stdoutPointsAt(join(dir, "missing.log")), false);
		// An existing file with a different inode cannot match either.
		const other = join(dir, "other.log");
		await Deno.writeTextFile(other, "different file\n");
		assertEquals(await stdoutPointsAt(other), false);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});
