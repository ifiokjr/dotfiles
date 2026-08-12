import { assert, assertEquals } from "@std/assert";
import { dirname, fromFileUrl, join } from "@std/path";
import { reloadGroupArgs, reloadSubcommand } from "../commands/reload.ts";

const cliDir = dirname(dirname(fromFileUrl(import.meta.url)));
const repoDir = dirname(cliDir);

Deno.test("reload keeps the Nix group symlink-only", () => {
	assertEquals(reloadSubcommand("nix"), "add");
	assertEquals(reloadGroupArgs("nix"), ["--only-files"]);
	assertEquals(reloadSubcommand("nushell"), "set");
	assertEquals(reloadGroupArgs("nushell"), []);
	assertEquals(reloadSubcommand("git"), "add");
	assertEquals(reloadGroupArgs("git"), []);
});

Deno.test("legacy reload keeps the Nix group out of hook groups", async () => {
	const script = await Deno.readTextFile(
		join(repoDir, "Configs/scripts/.local/bin/tuckr:reload"),
	);

	assert(script.includes('let hook_groups = ["nushell"]'));
	assert(script.includes("^tuckr add ...$tuckr_args --only-files $group"));
	assert(!script.includes('let hook_groups = ["nix" "nushell"]'));
});

Deno.test("Nix post-hook does not touch the tracked flake lock", async () => {
	const hook = await Deno.readTextFile(join(repoDir, "Hooks/nix/post.sh"));

	assert(!hook.includes("flake.lock"));
});
