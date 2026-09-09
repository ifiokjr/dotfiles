import { assertEquals } from "@std/assert";
import {
	cargoCleanAllArgs,
	fmtBytes,
	parseDfAvailableKilobytes,
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
