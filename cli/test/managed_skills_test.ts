import { assertEquals } from "@std/assert";
import { findManagedSkillConflicts } from "../lib/managed_skills.ts";
import { MATT_POCOCK_SOURCE } from "../lib/matt_pocock.ts";
import { PSTACK_SOURCE } from "../lib/pstack.ts";

Deno.test("managed external selections have no target-name conflicts", () => {
	assertEquals(
		findManagedSkillConflicts([PSTACK_SOURCE, MATT_POCOCK_SOURCE]),
		[],
	);
});

Deno.test("managed skill conflicts identify both sources", () => {
	assertEquals(
		findManagedSkillConflicts([
			{
				...PSTACK_SOURCE,
				displayName: "first",
				skills: [{ name: "duplicate", sourcePath: "first/duplicate" }],
			},
			{
				...MATT_POCOCK_SOURCE,
				displayName: "second",
				skills: [{ name: "duplicate", sourcePath: "second/duplicate" }],
			},
		]),
		["duplicate: first, second"],
	);
});
