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
				skills: ["greet"],
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
				skills: ["greet"],
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

/**
 * A discovery source ships a directory of one skill per child directory. The
 * static `skills` list is deliberately narrower than the checkout so the
 * tests prove discovery — not the list — decides what installs.
 */
function discoverySource(): ManagedSkillSource {
	return {
		displayName: "Discovery",
		manifestFile: ".discovery-source.json",
		repository: "example/discovery",
		ref: "main",
		skills: [{ name: "greet", sourcePath: "skills/greet" }],
		skillsDirectory: "skills",
		tempPrefix: "discovery-test-",
		transactionLabel: "discovery",
		userAgent: "dotfiles-cli-test",
	};
}

/**
 * Write a checkout with one skill per name (plus an assets directory without
 * a SKILL.md, which discovery must skip) and tar it where the fetch mock
 * serves it from.
 */
async function writeDiscoveryCheckout(
	checkoutDir: string,
	names: readonly string[],
): Promise<string> {
	const skillsDir = join(checkoutDir, "skills");

	await Deno.mkdir(join(skillsDir, "assets"), { recursive: true });
	await Deno.writeTextFile(
		join(skillsDir, "assets", "README.md"),
		"not a skill",
	);

	for (const name of names) {
		const skillDir = join(skillsDir, name);
		await Deno.mkdir(skillDir, { recursive: true });
		await Deno.writeTextFile(
			join(skillDir, "SKILL.md"),
			`---\nname: ${name}\ndescription: test\n---\n`,
		);
	}

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

Deno.test("discovery sync mirrors every skill the checkout ships", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "discovery-test-" });
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
		const archivePath = await writeDiscoveryCheckout(checkoutDir, [
			"greet",
			"fresh-skill",
		]);
		const restoreFetch = withMockedFetch(archivePath, TEST_SHA);
		const source = discoverySource();

		try {
			const result = await syncManagedSkills(source, dotfilesDir);

			assertEquals(result, {
				resolvedRef: "main",
				resolvedSha: TEST_SHA,
				skillCount: 2,
				skills: ["fresh-skill", "greet"],
			});

			// A skill the static list never named is installed, and the assets
			// directory without a SKILL.md is not treated as a skill.
			assertEquals(
				await exists(join(managedRoot, "fresh-skill", "SKILL.md"), {
					isFile: true,
				}),
				true,
			);
			assertEquals(await exists(join(managedRoot, "assets")), false);

			const manifest = JSON.parse(
				await Deno.readTextFile(join(managedRoot, ".discovery-source.json")),
			) as { skills: string[] };
			assertEquals(manifest.skills, ["fresh-skill", "greet"]);

			// The source's list now covers the discovered set, so verification
			// and conflict checks in the same process see the new skill.
			assertEquals(
				source.skills.map((skill) => skill.name),
				["fresh-skill", "greet"],
			);
		} finally {
			restoreFetch();
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("discovery sync drops skills upstream no longer ships", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "discovery-test-" });
	const dotfilesDir = join(tempDir, "dotfiles");
	const managedRoot = join(
		dotfilesDir,
		"Configs",
		"agents",
		".agents",
		"skills",
	);

	try {
		// Both checkouts tar into tempDir/source.tar.gz, and the fetch mock
		// reads that file at call time, so the second sync serves checkout two.
		const checkoutDir = join(tempDir, "checkout");
		const archivePath = await writeDiscoveryCheckout(checkoutDir, [
			"greet",
			"temporary",
		]);
		const restoreFetch = withMockedFetch(archivePath, TEST_SHA);

		try {
			await syncManagedSkills(discoverySource(), dotfilesDir);
			assertEquals(
				await exists(join(managedRoot, "temporary", "SKILL.md")),
				true,
			);

			// Rebuild the checkout with the skill gone; the helper only adds
			// files, so the stale skill directory has to go first.
			await Deno.remove(checkoutDir, { recursive: true });
			await writeDiscoveryCheckout(checkoutDir, ["greet"]);
			const second = await syncManagedSkills(discoverySource(), dotfilesDir);

			assertEquals(second.skills, ["greet"]);
			assertEquals(await exists(join(managedRoot, "temporary")), false);

			const manifest = JSON.parse(
				await Deno.readTextFile(join(managedRoot, ".discovery-source.json")),
			) as { skills: string[] };
			assertEquals(manifest.skills, ["greet"]);
		} finally {
			restoreFetch();
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("discovery sync refuses to replace a directory it does not own", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "discovery-test-" });
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
		// A locally authored skill (or another collection's directory) already
		// occupies the managed root, and neither the static list nor a manifest
		// records it as this source's own.
		const localSkill = join(managedRoot, "local-skill");
		await Deno.mkdir(localSkill, { recursive: true });
		await Deno.writeTextFile(join(localSkill, "SKILL.md"), "local");

		const archivePath = await writeDiscoveryCheckout(checkoutDir, [
			"greet",
			"local-skill",
		]);
		const restoreFetch = withMockedFetch(archivePath, TEST_SHA);

		try {
			await assertRejects(
				() => syncManagedSkills(discoverySource(), dotfilesDir),
				Error,
				"does not own",
			);

			// The refusal happens during discovery, before anything installs.
			assertEquals(
				await Deno.readTextFile(join(localSkill, "SKILL.md")),
				"local",
			);
			assertEquals(await exists(join(managedRoot, "greet")), false);
		} finally {
			restoreFetch();
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("discovery sync fails loudly when upstream ships no skills", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "discovery-test-" });
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
		const archivePath = await writeDiscoveryCheckout(checkoutDir, ["greet"]);
		const restoreFetch = withMockedFetch(archivePath, TEST_SHA);

		try {
			await syncManagedSkills(discoverySource(), dotfilesDir);

			// The checkout now ships only the assets directory, so discovery
			// would empty the collection; that must stop the update instead.
			// The helper only adds files, so clear the synced skill first.
			await Deno.remove(checkoutDir, { recursive: true });
			await writeDiscoveryCheckout(checkoutDir, []);

			await assertRejects(
				() => syncManagedSkills(discoverySource(), dotfilesDir),
				Error,
				"found no skills",
			);

			assertEquals(
				await exists(join(managedRoot, "greet", "SKILL.md"), {
					isFile: true,
				}),
				true,
			);
		} finally {
			restoreFetch();
		}
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});
