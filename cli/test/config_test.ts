import { assert, assertEquals } from "@std/assert";
import {
	detectPlatform,
	discoverGroups,
	resolveDotfilesDir,
} from "../lib/config.ts";

Deno.test("detectPlatform returns a supported platform label", () => {
	const platform = detectPlatform();

	assert(["macos", "linux", "windows", "bsd"].includes(platform));
});

Deno.test("discoverGroups finds repository config groups", async () => {
	const dotfilesDir = await resolveDotfilesDir();
	const groups = await discoverGroups(dotfilesDir);

	assert(groups.length > 0);
	assert(groups.includes("nix"));
	assertEquals(groups, groups.toSorted());
});
