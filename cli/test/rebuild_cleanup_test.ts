import { assertEquals, assertRejects } from "@std/assert";
import { cleanupRemovedScripts } from "../commands/rebuild.ts";

async function link(path: string, target: string) {
	await Deno.symlink(target, path);
}

Deno.test("cleanupRemovedScripts removes only dangling symlinks", async () => {
	const home = await Deno.makeTempDir({ prefix: "rebuild-cleanup-" });
	await Deno.mkdir(`${home}/.local/bin`, { recursive: true });

	try {
		// Dangling link where the removed script used to be deployed.
		await link(`${home}/.local/bin/rebuild`, "/nonexistent/target/rebuild");
		// A working symlink must survive.
		const liveTarget = `${home}/live-target`;
		await Deno.writeTextFile(liveTarget, "");
		await link(`${home}/.local/bin/tuckr:reload`, liveTarget);
		// A real file must survive even with the removed script's name.
		await Deno.writeTextFile(`${home}/.local/bin/dotfiles`, "#!/bin/sh\n");

		assertEquals(await cleanupRemovedScripts(home), 1);

		await assertRejects(() => Deno.lstat(`${home}/.local/bin/rebuild`));
		await Deno.lstat(`${home}/.local/bin/tuckr:reload`);
		await Deno.lstat(`${home}/.local/bin/dotfiles`);
	} finally {
		await Deno.remove(home, { recursive: true });
	}
});

Deno.test("cleanupRemovedScripts is a no-op without deployed links", async () => {
	const home = await Deno.makeTempDir({ prefix: "rebuild-cleanup-" });
	try {
		assertEquals(await cleanupRemovedScripts(home), 0);
	} finally {
		await Deno.remove(home, { recursive: true });
	}
});
