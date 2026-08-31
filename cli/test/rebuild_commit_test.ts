import { assertEquals } from "@std/assert";
import { dirname, join } from "@std/path";
import { commitRebuildChanges } from "../commands/rebuild.ts";
import { runCommand } from "../lib/config.ts";

const FLAKE = "Configs/nix/.config/nix/flake.lock";
const PNPM = "Configs/pnpm/.config/pnpm-global/pnpm-lock.yaml";
const SKILL = "Configs/agents/.agents/skills/.demo-source.json";

function git(dir: string, args: string[]) {
	return runCommand(["git", ...args], { cwd: dir, stdout: "piped" });
}

/** Scaffold a git repo with one tracked file per update-managed path. */
async function initRepo(): Promise<string> {
	const dir = await Deno.makeTempDir({ prefix: "rebuild-commit-" });

	async function write(path: string, content: string) {
		const target = join(dir, ...path.split("/"));
		await Deno.mkdir(dirname(target), { recursive: true });
		await Deno.writeTextFile(target, content);
	}

	await write(FLAKE, '{"lock": 1}');
	await write(SKILL, "{}");
	await write(PNPM, "lock: 1");
	await write("unrelated.txt", "original");

	await git(dir, ["init", "-q", "-b", "main"]);
	await git(dir, ["config", "user.email", "test@example.com"]);
	await git(dir, ["config", "user.name", "Test"]);
	await git(dir, ["add", "-A"]);
	await git(dir, ["commit", "-q", "-m", "init"]);

	return dir;
}

Deno.test(
	"commitRebuildChanges commits update files and leaves unrelated work",
	async () => {
		const dir = await initRepo();
		try {
			await Deno.writeTextFile(join(dir, FLAKE), '{"lock": 2}');
			await Deno.writeTextFile(join(dir, PNPM), "lock: 2");
			await Deno.writeTextFile(join(dir, SKILL), "---\nname: demo\n---\n");
			await Deno.writeTextFile(join(dir, "unrelated.txt"), "changed");

			assertEquals(await commitRebuildChanges(dir), true);

			const files = await git(dir, [
				"show",
				"--name-only",
				"--format=",
				"HEAD",
			]);
			assertEquals(
				(files.stdout ?? "").trim().split("\n").map((l) => l.trim())
					.filter((line) => line !== "")
					.toSorted(),
				[FLAKE, PNPM, SKILL].toSorted(),
			);

			const subject = await git(dir, ["log", "-1", "--format=%s"]);
			assertEquals(
				(subject.stdout ?? "").trim(),
				"chore: sync updates from dot rebuild --update",
			);

			// Unrelated work stays uncommitted.
			// Unrelated work stays uncommitted. Porcelain status is "XY <path>";
			// trim per line to compare paths regardless of padding.
			const status = await git(dir, ["status", "--porcelain"]);
			assertEquals(
				(status.stdout ?? "").split("\n").map((l) => l.trim()).filter((l) =>
					l !== ""
				),
				["M unrelated.txt"],
			);
		} finally {
			await Deno.remove(dir, { recursive: true });
		}
	},
);

Deno.test("commitRebuildChanges is a no-op when update files are clean", async () => {
	const dir = await initRepo();
	try {
		assertEquals(await commitRebuildChanges(dir), false);

		const count = await git(dir, ["rev-list", "--count", "HEAD"]);
		assertEquals((count.stdout ?? "").trim(), "1");
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});

Deno.test("commitRebuildChanges skips directories that are not git repos", async () => {
	const dir = await Deno.makeTempDir({ prefix: "rebuild-commit-" });
	try {
		assertEquals(await commitRebuildChanges(dir), false);
	} finally {
		await Deno.remove(dir, { recursive: true });
	}
});
