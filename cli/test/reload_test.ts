import { assert, assertEquals } from "@std/assert";
import { dirname, fromFileUrl, join } from "@std/path";
import { reloadGroupArgs, reloadSubcommand } from "../commands/reload.ts";

const cliDir = dirname(dirname(fromFileUrl(import.meta.url)));
const repoDir = dirname(cliDir);

Deno.test("reload keeps the Nix group symlink-only", () => {
	assertEquals(reloadSubcommand("nix"), "add");
	assertEquals(reloadSubcommand("agents"), "set");
	assertEquals(reloadGroupArgs("nix"), ["--only-files"]);
	assertEquals(reloadSubcommand("nushell"), "set");
	assertEquals(reloadGroupArgs("nushell"), []);
	assertEquals(reloadSubcommand("git"), "add");
	assertEquals(reloadGroupArgs("git"), []);
});

Deno.test("Nix post-hook does not touch the tracked flake lock", async () => {
	const hook = await Deno.readTextFile(join(repoDir, "Hooks/nix/post.sh"));

	assert(!hook.includes("flake.lock"));
});
