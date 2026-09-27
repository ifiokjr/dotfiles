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

Deno.test("collection ids resolve to their source skill names", () => {
	assertEquals(
		skillNamesForCollection("poteto"),
		PSTACK_SOURCE.skills.map((skill) => skill.name),
	);
	assertEquals(
		skillNamesForCollection("matt-pocock"),
		MATT_POCOCK_SOURCE.skills.map((skill) => skill.name),
	);
	assertEquals(skillNamesForCollection("nope"), []);
});

Deno.test("resolveDisabledSkills unions and sorts, ignoring duplicates", () => {
	assertEquals(resolveDisabledSkills([]), []);

	const poteto = resolveDisabledSkills(["poteto", "poteto"]);
	assertEquals(poteto, resolveDisabledSkills(["poteto"]));
	assertEquals(poteto.length, PSTACK_SOURCE.skills.length);
	assertEquals(poteto, [...poteto].toSorted());

	const both = resolveDisabledSkills(["poteto", "matt-pocock"]);
	assertEquals(
		both.length,
		PSTACK_SOURCE.skills.length + MATT_POCOCK_SOURCE.skills.length,
	);
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
		assertEquals([...disabledSkillNames(config)], []);
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

		const disabled = disabledSkillNames(config);
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

Deno.test("listSkillSelections reports the toggle state per collection", () => {
	const states = listSkillSelections({ disabledCollections: ["patrol"] });

	assertEquals(states.length, SKILL_COLLECTIONS.length);
	assertEquals(
		states.filter((state) => !state.enabled).map((state) => state.id),
		["patrol"],
	);
	assertEquals(
		states.find((state) => state.id === "patrol")?.skills,
		["patrol-setup", "patrol-write-test"],
	);
});

Deno.test("isCollectionDisabled reflects the config", () => {
	const config = { disabledCollections: ["poteto"] };

	assertEquals(isCollectionDisabled(config, "poteto"), true);
	assertEquals(isCollectionDisabled(config, "matt-pocock"), false);
});
