import { assertEquals, assertRejects } from "@std/assert";
import { dirname, join } from "@std/path";
import {
	compareDeterminateVersions,
	DETERMINATE_NIX_VERSION_PATH,
	determinateNixVersionPath,
	determinateTargetVersion,
	normalizeDeterminateVersion,
	parseDeterminateCurrentVersion,
	parseDeterminateVersions,
	readDeterminateNixPin,
} from "../commands/rebuild.ts";

// Modeled on real `determinate-nixd version` output, including the stderr
// WARN emitted when the features refresh times out (stderr is discarded by
// the caller, but the stdout body is unchanged).
const VERSION_OUTPUT =
	`2026-09-10T08:59:28.772784Z  WARN determinate_nixd::command::version: Failed to refresh system features and capabilities, e: deadline has elapsed
Determinate Nixd daemon version: 3.21.0
Determinate Nixd client version: 3.21.0
Latest version: 3.22.3

A new version of Determinate Nix is available. Please update Determinate Nix using the command line:

    sudo determinate-nixd upgrade`;

Deno.test("parseDeterminateVersions reads the client and latest versions", () => {
	assertEquals(parseDeterminateVersions(VERSION_OUTPUT), {
		current: "3.21.0",
		latest: "3.22.3",
	});
});

Deno.test("parseDeterminateVersions falls back to the daemon version", () => {
	assertEquals(
		parseDeterminateVersions(
			"Determinate Nixd daemon version: 3.21.0\nLatest version: 3.22.3",
		),
		{ current: "3.21.0", latest: "3.22.3" },
	);
});

Deno.test("parseDeterminateVersions returns null without a latest version", () => {
	assertEquals(
		parseDeterminateVersions("Determinate Nixd client version: 3.21.0"),
		null,
	);
});

Deno.test("parseDeterminateVersions returns null for unrecognized output", () => {
	assertEquals(parseDeterminateVersions(""), null);
	assertEquals(parseDeterminateVersions("nix (Nix) 2.34.6"), null);
});

Deno.test("compareDeterminateVersions orders semver-style versions", () => {
	assertEquals(compareDeterminateVersions("3.21.0", "3.21.0"), 0);
	assertEquals(compareDeterminateVersions("3.21.0", "3.22.3"), -1);
	assertEquals(compareDeterminateVersions("3.22.3", "3.21.0"), 1);
	assertEquals(compareDeterminateVersions("10.0.0", "9.9.9"), 1);
});

Deno.test("compareDeterminateVersions handles missing segments", () => {
	assertEquals(compareDeterminateVersions("3.21", "3.21.0"), 0);
	assertEquals(compareDeterminateVersions("3.21", "3.21.1"), -1);
	assertEquals(compareDeterminateVersions("4.0", "3.21.9"), 1);
});

Deno.test("parseDeterminateCurrentVersion reads up-to-date output", () => {
	const upToDate = `Determinate Nixd daemon version: 3.24.1
Determinate Nixd client version: 3.24.1

You are running the latest version of Determinate Nix.`;

	assertEquals(parseDeterminateCurrentVersion(upToDate), "3.24.1");
	assertEquals(parseDeterminateVersions(upToDate), null);
	assertEquals(parseDeterminateCurrentVersion("nix (Nix) 2.34.6"), null);
});

Deno.test("normalizeDeterminateVersion accepts dotted versions only", () => {
	assertEquals(normalizeDeterminateVersion(" 3.24.1\n"), "3.24.1");
	assertEquals(normalizeDeterminateVersion("v3.24.1"), "3.24.1");
	assertEquals(normalizeDeterminateVersion("3"), "3");
	assertEquals(normalizeDeterminateVersion(""), null);
	assertEquals(normalizeDeterminateVersion("latest"), null);
	assertEquals(normalizeDeterminateVersion("3.24.1; rm -rf /"), null);
});

function installed(current: string, latest: string | null) {
	return { current, latest };
}

Deno.test("determinateTargetVersion keeps the pin unless --update advances it", () => {
	assertEquals(
		determinateTargetVersion("3.24.1", installed("3.24.1", "3.25.0"), false),
		"3.24.1",
	);
	assertEquals(
		determinateTargetVersion("3.24.1", installed("3.24.1", "3.25.0"), true),
		"3.25.0",
	);
	assertEquals(
		determinateTargetVersion("3.24.1", installed("3.24.1", "3.24.1"), true),
		"3.24.1",
	);
	assertEquals(
		determinateTargetVersion("3.24.1", installed("3.24.1", "3.23.3"), true),
		"3.24.1",
	);
	// Already newest: no "Latest version" line, so the installed version is the
	// candidate and --update must not downgrade to the older pin.
	assertEquals(
		determinateTargetVersion("3.24.1", installed("3.25.0", null), true),
		"3.25.0",
	);
	assertEquals(
		determinateTargetVersion("3.24.1", installed("3.23.3", null), true),
		"3.24.1",
	);
	assertEquals(
		determinateTargetVersion("3.24.1", installed("3.24.1", "v3.25.0"), true),
		"3.25.0",
	);
	assertEquals(
		determinateTargetVersion(
			"3.24.1",
			installed("3.24.1", "not-a-version"),
			true,
		),
		"3.24.1",
	);
});

Deno.test("determinateNixVersionPath points at the tracked repo file", () => {
	assertEquals(
		determinateNixVersionPath("/repo"),
		join("/repo", DETERMINATE_NIX_VERSION_PATH),
	);
});

Deno.test("readDeterminateNixPin handles missing, valid, and invalid pins", async () => {
	const dir = await Deno.makeTempDir({ prefix: "determinate-pin-" });
	const pinPath = join(dir, DETERMINATE_NIX_VERSION_PATH);

	try {
		assertEquals(await readDeterminateNixPin(dir), null);

		await Deno.mkdir(dirname(pinPath), { recursive: true });
		await Deno.writeTextFile(pinPath, " v3.24.1 \n");
		assertEquals(await readDeterminateNixPin(dir), "3.24.1");

		await Deno.writeTextFile(pinPath, "latest\n");
		await assertRejects(
			() => readDeterminateNixPin(dir),
			Error,
			"Invalid Determinate Nix version pin",
		);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});
