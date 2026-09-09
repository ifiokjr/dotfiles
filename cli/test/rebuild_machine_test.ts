import { assertEquals } from "@std/assert";
import { homeDirectoryMismatch } from "../commands/rebuild.ts";

Deno.test("homeDirectoryMismatch reports darwin home mismatches", () => {
	assertEquals(
		homeDirectoryMismatch("aarch64-darwin", "minione", "/Users/mini01"),
		"\t$HOME (/Users/mini01) does not match machine.nix username minione (expected home: /Users/minione)",
	);
});

Deno.test("homeDirectoryMismatch accepts matching darwin home", () => {
	assertEquals(
		homeDirectoryMismatch("aarch64-darwin", "ifiokjr", "/Users/ifiokjr"),
		null,
	);
});

Deno.test("homeDirectoryMismatch expects /home/<username> on linux", () => {
	assertEquals(
		homeDirectoryMismatch("aarch64-linux", "ifiokjr", "/home/ifiokjr"),
		null,
	);

	assertEquals(
		homeDirectoryMismatch("aarch64-linux", "ifiokjr", "/Users/ifiokjr"),
		"\t$HOME (/Users/ifiokjr) does not match machine.nix username ifiokjr (expected home: /home/ifiokjr)",
	);
});

Deno.test("homeDirectoryMismatch tolerates unknown inputs", () => {
	assertEquals(homeDirectoryMismatch("", "", "/Users/ifiokjr"), null);
	assertEquals(
		homeDirectoryMismatch("aarch64-darwin", "ifiokjr", undefined),
		null,
	);
});
