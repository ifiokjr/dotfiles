import { assertEquals, assertRejects } from "@std/assert";
import {
	cargoCleanAllArgs,
	fmtBytes,
	isSudoRemovablePath,
	parseDfAvailableKilobytes,
	removeCachePath,
} from "../commands/clean.ts";

Deno.test("fmtBytes formats human-readable sizes", () => {
	assertEquals(fmtBytes(0), "0 B");
	assertEquals(fmtBytes(512), "512 B");
	assertEquals(fmtBytes(1024), "1.0 KB");
	assertEquals(fmtBytes(1536 * 1024), "1.5 MB");
	assertEquals(fmtBytes(3 * 1024 * 1024 * 1024), "3.0 GB");
	assertEquals(fmtBytes(1.5 * 1024 * 1024 * 1024 * 1024), "1.5 TB");
});

Deno.test("parseDfAvailableKilobytes parses macOS df output", () => {
	const macOS =
		"Filesystem     1024-blocks      Used Available Capacity iused ifree %iused  Mounted on\n" +
		"/dev/disk3s1s1  1953540352 1820434048 103106304    95%  1000     0   100%   /\n";
	assertEquals(parseDfAvailableKilobytes(macOS), 103106304 * 1024);
});

Deno.test("parseDfAvailableKilobytes parses Linux df output", () => {
	const linux =
		"Filesystem     1K-blocks      Used Available Use% Mounted on\n" +
		"/dev/nvme0n1p2 499052924 356317072 117380860  76% /\n";
	assertEquals(parseDfAvailableKilobytes(linux), 117380860 * 1024);
});

Deno.test("parseDfAvailableKilobytes returns null on bad input", () => {
	assertEquals(parseDfAvailableKilobytes(""), null);
	assertEquals(
		parseDfAvailableKilobytes("df: /: No such file or directory"),
		null,
	);
	assertEquals(
		parseDfAvailableKilobytes("Filesystem 1K-blocks Used Available\n"),
		null,
	);
});

Deno.test("cargoCleanAllArgs skips confirmation by default", () => {
	const args = cargoCleanAllArgs(0, "/home/test");
	assertEquals(args[0], "cargo-clean-all");
	assertEquals(args[1], "--yes");
	assertEquals(args.includes("--keep-days"), false);
	assertEquals(args[args.length - 1], "/home/test");
});

Deno.test("cargoCleanAllArgs keeps recent projects and skips system dirs", () => {
	const args = cargoCleanAllArgs(7, "/Users/test");
	assertEquals(args.includes("--keep-days"), true);
	assertEquals(args.includes("7"), true);
	assertEquals(args.filter((arg) => arg === "--skip").length, 3);
	assertEquals(args.includes("/Users/test/Library"), true);
	assertEquals(args.includes("/Users/test/Downloads"), true);
	assertEquals(args.includes("/Users/test/.Trash"), true);
});

async function pathExists(path: string): Promise<boolean> {
	try {
		await Deno.lstat(path);
		return true;
	} catch {
		return false;
	}
}

/**
 * Stand-in for the root-owned entries a stray `sudo npm install` leaves in a
 * cache: an unwritable directory blocks unlink with EPERM for the test user
 * just like root ownership does, and only a privileged removal can clear it.
 */
async function makeLockedCache(root: string): Promise<string> {
	const locked = `${root}/locked`;
	await Deno.mkdir(locked, { recursive: true });
	await Deno.writeTextFile(`${locked}/payload`, "x");
	await Deno.chmod(locked, 0o500);
	return locked;
}

/** Undo `makeLockedCache` when a test left the tree behind. */
async function unlockAndRemove(root: string, locked: string): Promise<void> {
	await Deno.chmod(locked, 0o700).catch(() => {});
	await Deno.remove(root, { recursive: true }).catch(() => {});
}

/**
 * Run `action` with a `sudo` shim first on PATH. The shim logs its argv and
 * then emulates root's `rm -rf`: the test's blocker is only an unwritable
 * directory, and root ignores permission bits, so granting write permission
 * stands in for CAP_DAC_OVERRIDE.
 */
async function withFakeSudo(
	script: (logPath: string) => string,
	action: (logPath: string) => Promise<void>,
): Promise<void> {
	const binDir = await Deno.makeTempDir({ prefix: "fake-sudo-" });
	const logPath = `${binDir}/calls.log`;
	const sudoPath = `${binDir}/sudo`;
	await Deno.writeTextFile(sudoPath, script(logPath));
	await Deno.chmod(sudoPath, 0o755);

	const originalPath = Deno.env.get("PATH") ?? "";
	Deno.env.set("PATH", `${binDir}:${originalPath}`);
	try {
		await action(logPath);
	} finally {
		Deno.env.set("PATH", originalPath);
		await Deno.remove(binDir, { recursive: true });
	}
}

const emulatedRootRm = (logPath: string) =>
	[
		"#!/bin/sh",
		`echo "$@" >> '${logPath}'`,
		`if [ "$1" = "-n" ]; then shift; fi`,
		// The test shim is only ever asked to remove the path it is handed.
		`target=""`,
		`for arg in "$@"; do target="$arg"; done`,
		`chmod -R u+rwX "$target" 2>/dev/null`,
		`rm -rf "$target"`,
		"",
	].join("\n");

Deno.test("isSudoRemovablePath allows only paths inside HOME", () => {
	assertEquals(
		isSudoRemovablePath("/Users/me/.npm/_cacache", "/Users/me"),
		true,
	);
	// HOME itself (with or without a trailing slash) is never removable.
	assertEquals(isSudoRemovablePath("/Users/me", "/Users/me"), false);
	assertEquals(isSudoRemovablePath("/Users/me/", "/Users/me"), false);
	// Neither is a sibling that merely shares the HOME prefix, an ancestor, or
	// a path a bad `pnpm store path` could report.
	assertEquals(isSudoRemovablePath("/Users/megan/.npm", "/Users/me"), false);
	assertEquals(isSudoRemovablePath("/Users", "/Users/me"), false);
	assertEquals(isSudoRemovablePath("/", "/Users/me"), false);
	assertEquals(isSudoRemovablePath("/tmp/.npm/_cacache", "/Users/me"), false);
	// A HOME that itself carries a trailing slash still matches.
	assertEquals(isSudoRemovablePath("/Users/me/.npm", "/Users/me/"), true);
});

Deno.test("removeCachePath removes a user-owned cache without sudo", async () => {
	const dir = await Deno.makeTempDir({ prefix: "clean-plain-" });
	await Deno.writeTextFile(`${dir}/payload`, "x");

	assertEquals(await removeCachePath(dir, false), false);
	assertEquals(await pathExists(dir), false);
});

Deno.test("removeCachePath retries with sudo for root-owned entries", async () => {
	const home = Deno.env.get("HOME") ?? "/tmp";
	const dir = await Deno.makeTempDir({ dir: home, prefix: ".clean-probe-" });
	const locked = await makeLockedCache(dir);
	try {
		await withFakeSudo(emulatedRootRm, async (logPath) => {
			assertEquals(await removeCachePath(dir, false), true);
			assertEquals(await pathExists(dir), false);
			// Interactive: sudo may prompt, so no -n.
			assertEquals(
				(await Deno.readTextFile(logPath)).trim(),
				`rm -rf ${dir}`,
			);
		});
	} finally {
		await unlockAndRemove(dir, locked);
	}
});

Deno.test("removeCachePath never prompts when unattended", async () => {
	const home = Deno.env.get("HOME") ?? "/tmp";
	const dir = await Deno.makeTempDir({ dir: home, prefix: ".clean-probe-" });
	const locked = await makeLockedCache(dir);
	try {
		await withFakeSudo(emulatedRootRm, async (logPath) => {
			assertEquals(await removeCachePath(dir, true), true);
			assertEquals(await pathExists(dir), false);
			// The scheduled --auto run must never sit on a password prompt.
			assertEquals(
				(await Deno.readTextFile(logPath)).trim(),
				`-n rm -rf ${dir}`,
			);
		});
	} finally {
		await unlockAndRemove(dir, locked);
	}
});

Deno.test("removeCachePath reports the denial when sudo fails", async () => {
	const home = Deno.env.get("HOME") ?? "/tmp";
	const dir = await Deno.makeTempDir({ dir: home, prefix: ".clean-probe-" });
	const locked = await makeLockedCache(dir);
	try {
		// sudo with no cached credentials and no TTY: the caller must see the
		// original permission error so it can print the manual command.
		await withFakeSudo(() => "#!/bin/sh\nexit 1\n", async () => {
			await assertRejects(
				() => removeCachePath(dir, true),
				Deno.errors.PermissionDenied,
			);
			assertEquals(await pathExists(dir), true);
		});
	} finally {
		await unlockAndRemove(dir, locked);
	}
});

Deno.test("removeCachePath never escalates outside HOME", async () => {
	// Only the path guard stands between a bad value from `pnpm store path` (or
	// a platform lookup) and `sudo rm -rf`, so it must refuse before sudo runs.
	const dir = await Deno.makeTempDir({ prefix: "clean-outside-" });
	const locked = await makeLockedCache(dir);
	try {
		await withFakeSudo(emulatedRootRm, async (logPath) => {
			await assertRejects(
				() => removeCachePath(dir, false),
				Deno.errors.PermissionDenied,
			);
			assertEquals(await pathExists(logPath), false);
			assertEquals(await pathExists(dir), true);
		});
	} finally {
		await unlockAndRemove(dir, locked);
	}
});
