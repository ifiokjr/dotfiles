import { assertEquals, assertRejects } from "@std/assert";
import { exists } from "@std/fs";
import { join } from "@std/path";
import {
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "../lib/managed_skills.ts";

const TEST_SHA = "0123456789abcdef0123456789abcdef01234567";

const DEMO_SOURCE: ManagedSkillSource = {
	displayName: "Demo",
	manifestFile: ".demo-source.json",
	repository: "example/demo",
	ref: "main",
	skills: [{ name: "greet", sourcePath: "skills/greet" }],
	tempPrefix: "demo-test-",
	transactionLabel: "demo",
	userAgent: "dotfiles-cli-test",
};

const TEST_TAG = "v1.2.3";

const RELEASE_SOURCE: ManagedSkillSource = {
	channel: "release",
	displayName: "Demo",
	manifestFile: ".demo-source.json",
	repository: "example/demo",
	ref: "main",
	skills: [{ name: "greet", sourcePath: "skills/greet" }],
	tempPrefix: "demo-test-",
	transactionLabel: "demo",
	userAgent: "dotfiles-cli-test",
};

async function writeDemoCheckout(checkoutDir: string): Promise<string> {
	const skillDir = join(checkoutDir, "skills", "greet");
	await Deno.mkdir(skillDir, { recursive: true });
	await Deno.writeTextFile(
		join(skillDir, "SKILL.md"),
		"---\nname: greet\ndescription: test\n---\n",
	);

	const archivePath = join(checkoutDir, "..", "source.tar.gz");
	const command = new Deno.Command("tar", {
		args: ["-czf", archivePath, "-C", checkoutDir, "."],
		stdout: "null",
		stderr: "null",
	});
	const output = await command.output();
	assertEquals(output.success, true);

	return archivePath;
}

function withMockedFetch(archivePath: string, sha: string): () => void {
	const originalFetch = globalThis.fetch;

	globalThis.fetch = ((input: URL | RequestInfo, _init?: RequestInit) => {
		const url = String(input instanceof Request ? input.url : input);

		if (url.startsWith("https://api.github.com/")) {
			return Promise.resolve(
				new Response(JSON.stringify({ sha }), { status: 200 }),
			);
		}

		if (url.startsWith("https://codeload.github.com/")) {
			return Promise.resolve(
				new Response(Deno.readFileSync(archivePath), { status: 200 }),
			);
		}

		return originalFetch(input);
	}) as typeof fetch;

	return () => {
		globalThis.fetch = originalFetch;
	};
}

/** Mock GitHub so the latest release resolves to TEST_TAG, and the tag to sha. */
function withMockedReleaseFetch(
	archivePath: string,
	tag: string,
	sha: string,
): () => void {
	const originalFetch = globalThis.fetch;

	globalThis.fetch = ((input: URL | RequestInfo, _init?: RequestInit) => {
		const url = String(input instanceof Request ? input.url : input);

		if (url === "https://api.github.com/repos/example/demo/releases/latest") {
			return Promise.resolve(
				new Response(JSON.stringify({ tag_name: tag }), { status: 200 }),
			);
		}

		if (url.startsWith("https://api.github.com/repos/example/demo/commits/")) {
			return Promise.resolve(
				new Response(JSON.stringify({ sha }), { status: 200 }),
			);
		}

		if (url.startsWith("https://codeload.github.com/")) {
			return Promise.resolve(
				new Response(Deno.readFileSync(archivePath), { status: 200 }),
			);
		}

		return originalFetch(input);
	}) as typeof fetch;

	return () => {
		globalThis.fetch = originalFetch;
	};
}

Deno.test("managed skill sync downloads, extracts and installs from GitHub", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "managed-sync-test-" });
	const dotfilesDir = join(tempDir, "dotfiles");
	const checkoutDir = join(tempDir, "checkout");
	const managedRoot = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);

	try {
		const archivePath = await writeDemoCheckout(checkoutDir);
		const restoreFetch = withMockedFetch(archivePath, TEST_SHA);

		try {
			const result = await syncManagedSkills(DEMO_SOURCE, dotfilesDir);

			assertEquals(result, {
				resolvedRef: "main",
				resolvedSha: TEST_SHA,
				skillCount: 1,
			});
			assertEquals(
				await exists(join(managedRoot, "greet", "SKILL.md"), {
					isFile: true,
				}),
				true,
			);

			const manifest = JSON.parse(
				await Deno.readTextFile(join(managedRoot, ".demo-source.json")),
			) as { ref: string; resolvedSha: string; skills: string[] };
			assertEquals(manifest.ref, "main");
			assertEquals(manifest.resolvedSha, TEST_SHA);
			assertEquals(manifest.skills, ["greet"]);
		} finally {
			restoreFetch();
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("managed skill sync rejects a non-commit resolved ref", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "managed-sync-test-" });
	const checkoutDir = join(tempDir, "checkout");

	try {
		const archivePath = await writeDemoCheckout(checkoutDir);
		const restoreFetch = withMockedFetch(archivePath, "refs/heads/main");

		try {
			await assertRejects(
				() => syncManagedSkills(DEMO_SOURCE, join(tempDir, "dotfiles")),
				Error,
				"Invalid Demo commit SHA",
			);
		} finally {
			restoreFetch();
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("release-channel sync pins skills to the latest GitHub release", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "managed-sync-test-" });
	const checkoutDir = join(tempDir, "checkout");
	const dotfilesDir = join(tempDir, "dotfiles");
	const managedRoot = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);

	try {
		const archivePath = await writeDemoCheckout(checkoutDir);
		const restoreFetch = withMockedReleaseFetch(
			archivePath,
			TEST_TAG,
			TEST_SHA,
		);

		try {
			const result = await syncManagedSkills(RELEASE_SOURCE, dotfilesDir);

			assertEquals(result, {
				resolvedRef: TEST_TAG,
				resolvedSha: TEST_SHA,
				skillCount: 1,
			});

			const manifest = JSON.parse(
				await Deno.readTextFile(join(managedRoot, ".demo-source.json")),
			) as { ref: string; resolvedSha: string };
			assertEquals(manifest.ref, TEST_TAG);
			assertEquals(manifest.resolvedSha, TEST_SHA);
		} finally {
			restoreFetch();
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("release-channel sync fails when the source has no releases", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "managed-sync-test-" });

	try {
		const originalFetch = globalThis.fetch;

		globalThis.fetch = ((input: URL | RequestInfo, _init?: RequestInit) => {
			const url = String(input instanceof Request ? input.url : input);

			if (url === "https://api.github.com/repos/example/demo/releases/latest") {
				return Promise.resolve(new Response("Not Found", { status: 404 }));
			}

			return Promise.reject(new Error(`unexpected fetch: ${url}`));
		}) as typeof fetch;

		try {
			await assertRejects(
				() => syncManagedSkills(RELEASE_SOURCE, join(tempDir, "dotfiles")),
				Error,
				"Failed to resolve the latest Demo release: HTTP 404",
			);
		} finally {
			globalThis.fetch = originalFetch;
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("deployment verification flags symlinks outside the managed root", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "managed-sync-test-" });
	const dotfilesDir = join(tempDir, "dotfiles");
	const homeDir = join(tempDir, "home");
	const managedRoot = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);

	try {
		const managedSkill = join(managedRoot, "greet");
		await Deno.mkdir(managedSkill, { recursive: true });
		await Deno.writeTextFile(join(managedSkill, "SKILL.md"), "greet");

		const foreignDir = join(tempDir, "elsewhere", "greet");
		await Deno.mkdir(foreignDir, { recursive: true });
		await Deno.writeTextFile(join(foreignDir, "SKILL.md"), "impostor");

		const deployedRoot = join(homeDir, ".agents", "skills");
		await Deno.mkdir(deployedRoot, { recursive: true });
		await Deno.symlink(foreignDir, join(deployedRoot, "greet"), {
			type: "dir",
		});

		assertEquals(
			await verifyManagedSkillDeployment(DEMO_SOURCE, dotfilesDir, homeDir),
			["greet/SKILL.md: not dotfiles-managed"],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
