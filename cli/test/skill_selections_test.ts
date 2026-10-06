import { assertEquals, assertThrows } from "@std/assert";
import { join } from "@std/path";
import { MATT_POCOCK_SOURCE } from "../lib/matt_pocock.ts";
import { PSTACK_SOURCE } from "../lib/pstack.ts";
import {
	disabledSkillNames,
	isCollectionDisabled,
	listSkillSelections,
	readSkillSelections,
	renderDisabledSkillsList,
	renderSkillSelections,
	resolveDisabledSkills,
	SKILL_COLLECTION_IDS,
	SKILL_COLLECTIONS,
	SKILL_SELECTIONS_RELATIVE,
	skillNamesForCollection,
	validateDisabledCollections,
	writeSkillSelections,
} from "../lib/skill_selections.ts";

Deno.test("collection ids are unique and cover every managed source", () => {
	const ids = SKILL_COLLECTIONS.map((collection) => collection.id);

	assertEquals(new Set(ids).size, ids.length);
	assertEquals(ids, [...SKILL_COLLECTION_IDS]);
});

Deno.test("collection ids resolve to their source skill names", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "skill-sel-names-" });

	try {
		// The temp dir holds no manifests, so the static lists answer.
		assertEquals(
			await skillNamesForCollection("poteto", tempDir),
			PSTACK_SOURCE.skills.map((skill) => skill.name),
		);
		assertEquals(
			await skillNamesForCollection("matt-pocock", tempDir),
			MATT_POCOCK_SOURCE.skills.map((skill) => skill.name),
		);
		assertEquals(await skillNamesForCollection("nope", tempDir), []);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("a discovery collection reads its skills from the manifest", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "skill-sel-manifest-" });
	const managedRoot = join(tempDir, "Configs", "agents", ".agents", "skills");

	try {
		await Deno.mkdir(managedRoot, { recursive: true });
		await Deno.writeTextFile(
			join(managedRoot, ".pstack-source.json"),
			JSON.stringify({
				repository: "https://github.com/cursor/plugins",
				ref: "main",
				resolvedSha: "a".repeat(40),
				skills: ["how", "why"],
				version: 1,
			}),
		);

		// The manifest is what every sync rewrites, so it — not the static
		// snapshot in pstack.ts — records what a discovery collection tracks.
		assertEquals(await skillNamesForCollection("poteto", tempDir), [
			"how",
			"why",
		]);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("resolveDisabledSkills unions and sorts, ignoring duplicates", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "skill-sel-resolve-" });

	try {
		assertEquals(await resolveDisabledSkills([], tempDir), []);

		const poteto = await resolveDisabledSkills(["poteto", "poteto"], tempDir);
		assertEquals(poteto, await resolveDisabledSkills(["poteto"], tempDir));
		assertEquals(poteto.length, PSTACK_SOURCE.skills.length);
		assertEquals(poteto, [...poteto].toSorted());

		const both = await resolveDisabledSkills(
			["poteto", "matt-pocock"],
			tempDir,
		);
		assertEquals(
			both.length,
			PSTACK_SOURCE.skills.length + MATT_POCOCK_SOURCE.skills.length,
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("unknown collection ids are rejected", () => {
	assertThrows(
		() => validateDisabledCollections(["typo"]),
		Error,
		"Unknown skill collection id",
	);
	assertThrows(
		() => validateDisabledCollections([7]),
		Error,
		"must be an array of collection ids",
	);
	assertThrows(
		() => validateDisabledCollections("poteto"),
		Error,
		"must be an array of collection ids",
	);
});

Deno.test("a missing config file means everything is enabled", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "skill-sel-missing-" });

	try {
		const config = await readSkillSelections(tempDir);
		assertEquals(config.disabledCollections, []);
		assertEquals([...await disabledSkillNames(config, tempDir)], []);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("writeSkillSelections round-trips through disk", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "skill-sel-round-" });

	try {
		await writeSkillSelections(tempDir, {
			disabledCollections: ["poteto", "matt-pocock"],
		});

		const config = await readSkillSelections(tempDir);
		assertEquals(config.disabledCollections, ["matt-pocock", "poteto"]);

		const disabled = await disabledSkillNames(config, tempDir);
		assertEquals(disabled.has("unslop"), true);
		assertEquals(disabled.has("diagnosing-bugs"), true);
		// A skill outside the disabled collections stays enabled.
		assertEquals(disabled.has("patrol-setup"), false);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("the rendered TOML survives a re-read", async () => {
	const rendered = renderSkillSelections({
		disabledCollections: ["poteto"],
	});
	const tempDir = await Deno.makeTempDir({ prefix: "skill-sel-toml-" });

	try {
		const path = join(tempDir, SKILL_SELECTIONS_RELATIVE);
		await Deno.mkdir(join(tempDir, "Configs/agents/.config/agents"), {
			recursive: true,
		});
		await Deno.writeTextFile(path, rendered);

		const config = await readSkillSelections(tempDir);
		assertEquals(config.disabledCollections, ["poteto"]);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("the derived list has one bare name per line for the hook", () => {
	const rendered = renderDisabledSkillsList(["alpha", "beta"]);

	assertEquals(rendered.includes("\nalpha\n"), true);
	assertEquals(rendered.endsWith("beta\n"), true);
	// The hook compares whole lines, so a name must never be quoted, indented,
	// or otherwise decorated in a way that would stop matching.
	for (const line of rendered.split("\n")) {
		if (line === "" || line.startsWith("#")) continue;
		assertEquals(line, line.trim());
		assertEquals(/^[A-Za-z0-9._-]+$/.test(line), true);
	}
});

Deno.test("an empty disabled list renders only the header", () => {
	const rendered = renderDisabledSkillsList([]);

	for (const line of rendered.split("\n")) {
		if (line === "") continue;
		assertEquals(line.startsWith("#"), true);
	}
});

Deno.test("listSkillSelections reports the toggle state per collection", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "skill-sel-list-" });

	try {
		const states = await listSkillSelections(
			{ disabledCollections: ["patrol"] },
			tempDir,
		);

		assertEquals(states.length, SKILL_COLLECTIONS.length);
		assertEquals(
			states.filter((state) => !state.enabled).map((state) => state.id),
			["patrol"],
		);
		assertEquals(
			states.find((state) => state.id === "patrol")?.skills,
			["patrol-setup", "patrol-write-test"],
		);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("isCollectionDisabled reflects the config", () => {
	const config = { disabledCollections: ["poteto"] };

	assertEquals(isCollectionDisabled(config, "poteto"), true);
	assertEquals(isCollectionDisabled(config, "matt-pocock"), false);
});
