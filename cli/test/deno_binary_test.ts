import { assert, assertEquals } from "@std/assert";
import { denoCandidatePaths } from "../lib/config.ts";

Deno.test("denoCandidatePaths prefers DENO_INSTALL and includes nix-darwin profiles", () => {
	const paths = denoCandidatePaths("/Users/mini01", "mini01", "/opt/deno");

	assertEquals(paths[0], "/opt/deno/bin/deno");
	assert(paths.includes("/etc/profiles/per-user/mini01/bin/deno"));
	assert(paths.includes("/Users/mini01/.deno/bin/deno"));
});

Deno.test("denoCandidatePaths omits roots it cannot build", () => {
	const paths = denoCandidatePaths("", "");

	assert(!paths.includes("/etc/profiles/per-user//bin/deno"));
	assert(!paths.some((path) => path === ""));
});
