import { assertEquals } from "@std/assert";
import {
	compareDeterminateVersions,
	parseDeterminateVersions,
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
