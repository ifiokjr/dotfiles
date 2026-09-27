/**
 * Managed skill collections, and the toggle that disables them.
 *
 * Disabling a collection leaves its files in the repository, so `dot rebuild
 * --update` keeps refreshing them, and strips the skills out of the deployed
 * harness directories instead. Nothing is deleted, so re-enabling is one
 * command and comparing your agents with and without a collection costs
 * nothing but a redeploy.
 *
 * There are two files, each with one job:
 *
 * - `skills.toml` records intent. It is human-editable, deployed to
 *   `~/.config/agents/skills.toml`, and only ever parsed by the CLI.
 * - `.disabled-skills` is derived from it and lists the resolved skill names,
 *   one per line. `Hooks/agents/post.sh` reads it during deployment, because
 *   bash cannot parse TOML and the formatter is free to reflow the array in the
 *   file above.
 */

import { exists } from "@std/fs";
import { dirname, join, relative } from "@std/path";
import { parse as parseToml, stringify as stringifyToml } from "@std/toml";
import type { ManagedSkillSource } from "./managed_skills.ts";
import { MATT_POCOCK_SOURCE } from "./matt_pocock.ts";
import { MDT_SOURCE } from "./mdt.ts";
import { MONOCHANGE_SOURCE } from "./monochange.ts";
import { PATROL_SOURCE } from "./patrol.ts";
import { PINA_SOURCE } from "./pina.ts";
import { PSTACK_SOURCE } from "./pstack.ts";

/** User-editable intent, deployed to `~/.config/agents/skills.toml`. */
export const SKILL_SELECTIONS_RELATIVE =
	"Configs/agents/.config/agents/skills.toml";

/** The managed skills root, within a `Configs/agents` tree. */
const SKILLS_ROOT_SUFFIX = ".agents/skills";

/**
 * Derived skill-name list for the deploy hook.
 *
 * It lives beside the skills it describes, next to the per-source manifests,
 * and is deployed to `~/.agents/skills/.disabled-skills` like they are.
 */
export const DISABLED_SKILLS_LIST_RELATIVE =
	"Configs/agents/.agents/skills/.disabled-skills";

export interface SkillCollection {
	/** Stable id used in the config file and on the command line. */
	id: string;
	/** What the id refers to, for `dot skills list` and error messages. */
	summary: string;
	source: ManagedSkillSource;
}

/** Every externally managed collection, in the order `dot skills list` shows. */
export const SKILL_COLLECTIONS: readonly SkillCollection[] = [
	{
		id: "poteto",
		summary: "Poteto's P-Stack (cursor/plugins)",
		source: PSTACK_SOURCE,
	},
	{
		id: "matt-pocock",
		summary: "Matt Pocock engineering and productivity skills",
		source: MATT_POCOCK_SOURCE,
	},
	{
		id: "patrol",
		summary: "Patrol Flutter integration testing",
		source: PATROL_SOURCE,
	},
	{ id: "mdt", summary: "mdt documentation tooling", source: MDT_SOURCE },
	{
		id: "monochange",
		summary: "monochange release tooling",
		source: MONOCHANGE_SOURCE,
	},
	{ id: "pina", summary: "pina Solana program framework", source: PINA_SOURCE },
];

export const SKILL_COLLECTION_IDS: readonly string[] = SKILL_COLLECTIONS.map(
	(collection) => collection.id,
);

export interface SkillSelectionConfig {
	/** Collection ids that stay out of the agent skill directories. */
	disabledCollections: readonly string[];
}

export interface SkillSelectionState {
	id: string;
	summary: string;
	enabled: boolean;
	skills: readonly string[];
}

/** Skill names owned by one collection, in declaration order. */
export function skillNamesForCollection(id: string): readonly string[] {
	const collection = SKILL_COLLECTIONS.find((entry) => entry.id === id);
	return collection?.source.skills.map((skill) => skill.name) ?? [];
}

/** Resolve collection ids to the skill names they contribute, sorted. */
export function resolveDisabledSkills(
	collectionIds: readonly string[],
): string[] {
	const names = new Set<string>();

	for (const id of collectionIds) {
		for (const name of skillNamesForCollection(id)) {
			names.add(name);
		}
	}

	return [...names].toSorted();
}

/**
 * Read the toggle state.
 *
 * A missing file means everything is enabled, so a fresh clone and a machine
 * that never touched the toggle both work with no extra step.
 */
export async function readSkillSelections(
	dotfilesDir: string,
): Promise<SkillSelectionConfig> {
	const configPath = join(dotfilesDir, SKILL_SELECTIONS_RELATIVE);

	if (!(await exists(configPath, { isFile: true }))) {
		return { disabledCollections: [] };
	}

	let parsed: unknown;

	try {
		parsed = parseToml(await Deno.readTextFile(configPath));
	} catch (error) {
		const message = error instanceof Error ? error.message : String(error);
		throw new Error(
			`${SKILL_SELECTIONS_RELATIVE} is not valid TOML: ${message}`,
			{ cause: error },
		);
	}

	if (!isObject(parsed)) {
		throw new Error(`${SKILL_SELECTIONS_RELATIVE} must contain a table`);
	}

	return validateDisabledCollections(parsed.disabled_collections ?? []);
}

/** Normalize and validate a list of collection ids. */
export function validateDisabledCollections(
	value: unknown,
): SkillSelectionConfig {
	if (!Array.isArray(value) || value.some((id) => typeof id !== "string")) {
		throw new Error(
			`"disabled_collections" must be an array of collection ids`,
		);
	}

	const unknown = (value as string[]).filter((id) =>
		!SKILL_COLLECTION_IDS.includes(id)
	);

	if (unknown.length > 0) {
		throw new Error(
			`Unknown skill collection id(s): ${unknown.join(", ")}. Valid ids: ${
				SKILL_COLLECTION_IDS.join(", ")
			}`,
		);
	}

	return { disabledCollections: [...new Set(value as string[])].toSorted() };
}

/** Render the intent file, including its explanatory header. */
export function renderSkillSelections(config: SkillSelectionConfig): string {
	const body = stringifyToml({
		disabled_collections: [...config.disabledCollections],
	});

	return `# Managed skill collections that stay out of the agent skill directories.
#
# A disabled collection keeps its files in the repository, so \`dot rebuild
# --update\` still refreshes it, but its skills are stripped from the deployed
# harness directories. Nothing is deleted, so re-enabling restores it exactly.
#
# Prefer the CLI, which rewrites this file and redeploys for you:
#   dot skills list
#   dot skills disable <collection>
#   dot skills enable <collection>
#
# Hand-edit the list below, then run \`dot skills apply\`.
#
# Valid collection ids: ${SKILL_COLLECTION_IDS.join(", ")}
${body}`;
}

/**
 * Render the derived name list the deploy hook reads.
 *
 * One name per line with no quoting, so the hook can match it with a plain
 * whole-line comparison. Comments are fine: a name never starts with "#".
 */
export function renderDisabledSkillsList(
	disabledSkills: readonly string[],
): string {
	const header = `# Generated by \`dot skills\` from ${
		SKILL_SELECTIONS_RELATIVE.replace(
			"Configs/agents/.config/agents/",
			"",
		)
	}.
# Skills listed here are stripped from the agent skill directories by
# Hooks/agents/post.sh. Edit the TOML file instead of this one.

`;

	return header + disabledSkills.map((name) => `${name}\n`).join("");
}

/** Report every collection with its current toggle state. */
export function listSkillSelections(
	config: SkillSelectionConfig,
): SkillSelectionState[] {
	return SKILL_COLLECTIONS.map((collection) => ({
		id: collection.id,
		summary: collection.summary,
		enabled: !isCollectionDisabled(config, collection.id),
		skills: collection.source.skills.map((skill) => skill.name),
	}));
}

export function isCollectionDisabled(
	config: SkillSelectionConfig,
	id: string,
): boolean {
	return config.disabledCollections.includes(id);
}

/** Id of the managed collection owning a source, when there is one. */
export function collectionIdForSource(
	source: ManagedSkillSource,
): string | undefined {
	return SKILL_COLLECTIONS.find((collection) => collection.source === source)
		?.id;
}

/** Write both files: the edited intent and the derived hook list. */
export async function writeSkillSelections(
	dotfilesDir: string,
	config: SkillSelectionConfig,
) {
	const disabledSkills = resolveDisabledSkills(config.disabledCollections);
	const intentPath = join(dotfilesDir, SKILL_SELECTIONS_RELATIVE);
	const listPath = join(dotfilesDir, DISABLED_SKILLS_LIST_RELATIVE);

	await Deno.mkdir(dirname(intentPath), { recursive: true });
	await Deno.mkdir(dirname(listPath), { recursive: true });

	await Deno.writeTextFile(intentPath, renderSkillSelections(config));
	await Deno.writeTextFile(
		listPath,
		renderDisabledSkillsList(disabledSkills),
	);
	await reconcileCompatibilityLinks(dotfilesDir, config);
}

/**
 * Keep the tracked Pi compatibility links in step with the toggle.
 *
 * These links live in the repo and are deployed by Tuckr, so a disabled
 * collection has to drop them or Tuckr would keep installing dead links into
 * `~/.pi/agent/skills`. They are derived, so removing and recreating them is
 * safe; a real directory at one of these paths belongs to the user and is left
 * alone.
 */
async function reconcileCompatibilityLinks(
	dotfilesDir: string,
	config: SkillSelectionConfig,
) {
	const disabled = new Set(resolveDisabledSkills(config.disabledCollections));

	for (const collection of SKILL_COLLECTIONS) {
		for (const root of collection.source.compatibilityRoots ?? []) {
			for (const skill of collection.source.skills) {
				const linkPath = join(
					dotfilesDir,
					"Configs",
					"agents",
					root,
					skill.name,
				);
				const isLink = await isSymlink(linkPath);

				if (disabled.has(skill.name)) {
					if (isLink) await Deno.remove(linkPath);
					continue;
				}

				if (isLink) continue;

				// Absent or a real path: create only when nothing is there.
				if (await pathExists(linkPath)) continue;

				await Deno.mkdir(dirname(linkPath), { recursive: true });
				await Deno.symlink(
					relative(dirname(linkPath), activeSkillPath(dotfilesDir, skill.name)),
					linkPath,
				);
			}
		}
	}
}

/** Repo-relative path of a skill in the active managed skills root. */
function activeSkillPath(dotfilesDir: string, skillName: string): string {
	return join(
		dotfilesDir,
		"Configs",
		"agents",
		SKILLS_ROOT_SUFFIX,
		skillName,
	);
}

async function isSymlink(path: string): Promise<boolean> {
	try {
		return (await Deno.lstat(path)).isSymlink;
	} catch {
		return false;
	}
}

async function pathExists(path: string): Promise<boolean> {
	try {
		await Deno.stat(path);
		return true;
	} catch {
		return false;
	}
}

/** Skill names the deploy hook should keep out of the harness directories. */
export function disabledSkillNames(
	config: SkillSelectionConfig,
): ReadonlySet<string> {
	return new Set(resolveDisabledSkills(config.disabledCollections));
}

function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}
