import { assert, assertEquals } from "@std/assert";
import { dirname, join } from "@std/path";
import {
	ensureDotCliLinks,
	resolveDotCliBinary,
	resolveTuckrDir,
} from "../lib/config.ts";

/** Run a test body with HOME pointing at a throwaway directory. */
async function withTempHome(body: (home: string) => Promise<void> | void) {
	const previousHome = Deno.env.get("HOME");
	const home = await Deno.makeTempDir();

	try {
		Deno.env.set("HOME", home);
		await body(home);
	} finally {
		if (previousHome === undefined) {
			Deno.env.delete("HOME");
		} else {
			Deno.env.set("HOME", previousHome);
		}

		await Deno.remove(home, { recursive: true });
	}
}

/** Create a stand-in for the compiled CLI binary in a checkout. */
async function writeBinary(dotfilesDir: string): Promise<string> {
	const binary = join(dotfilesDir, "Configs/scripts/.local/bin/dotfiles");
	await Deno.mkdir(dirname(binary), { recursive: true });
	await Deno.writeTextFile(binary, "#!/bin/sh\n");
	return binary;
}

Deno.test("ensureDotCliLinks creates, keeps, and repairs the CLI links", async () => {
	await withTempHome(async (home) => {
		const checkout = join(home, "Developer/.dotfiles");
		const binary = await writeBinary(checkout);
		const dotfilesLink = join(home, ".local/bin/dotfiles");
		const dotLink = join(home, ".local/bin/dot");

		const created = await ensureDotCliLinks(binary);
		assert(created.changed);
		assertEquals(created.dotfilesLink, dotfilesLink);
		assertEquals(created.dotLink, dotLink);
		assertEquals(await Deno.readLink(dotfilesLink), binary);
		assertEquals(await Deno.readLink(dotLink), dotfilesLink);

		// A second run must not churn links that are already correct.
		const stable = await ensureDotCliLinks(binary);
		assert(!stable.changed);
		assertEquals(await Deno.readLink(dotfilesLink), binary);

		// A link left behind by an older install (pointing into another
		// checkout) is a Tuckr conflict; it gets repointed, not just recreated.
		await Deno.remove(dotfilesLink);
		await Deno.symlink(join(home, "elsewhere/dotfiles"), dotfilesLink);
		const repaired = await ensureDotCliLinks(binary);
		assert(repaired.changed);
		assertEquals(await Deno.readLink(dotfilesLink), binary);
	});
});

Deno.test("resolveDotCliBinary prefers the Tuckr checkout binary", async () => {
	await withTempHome(async (home) => {
		const checkout = join(home, "Developer/.dotfiles");
		const compiled = await writeBinary(checkout);

		// No Tuckr checkout yet: the compiled binary is the only option.
		assertEquals(await resolveDotCliBinary(compiled), compiled);

		// Standard layout: the Tuckr location is a symlink to the checkout.
		const tuckrDir = resolveTuckrDir();
		await Deno.mkdir(dirname(tuckrDir), { recursive: true });
		await Deno.symlink(checkout, tuckrDir);
		const deployed = join(tuckrDir, "Configs/scripts/.local/bin/dotfiles");
		assertEquals(await resolveDotCliBinary(compiled), deployed);

		// Separate checkout: the Tuckr location is a clone with its own binary.
		await Deno.remove(tuckrDir);
		assertEquals(await writeBinary(tuckrDir), deployed);
		assertEquals(await resolveDotCliBinary(compiled), deployed);
	});
});

Deno.test("resolveTuckrDir stays inside HOME", async () => {
	await withTempHome((home) => {
		const tuckrDir = resolveTuckrDir();

		assert(tuckrDir.startsWith(home));
	});
});
