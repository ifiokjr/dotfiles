/**
 * `dotfiles skills` — Turn managed skill collections on and off.
 *
 * Disabling a collection records it in `skills.toml` and redeploys the agents
 * group, which strips those skills from every harness skill directory while
 * leaving the files in the repository. Enabling reverses it. Neither direction
 * touches the skill content, so comparing your agents with and without a
 * collection is two commands.
 */

import { Command } from "@cliffy/command";
import {
	printError,
	printHeader,
	printInfo,
	printSuccess,
	resolveDotfilesDir,
	runCommand,
} from "../lib/config.ts";
import { repairAgentSkillDeployment } from "../lib/managed_skills.ts";
import {
	isCollectionDisabled,
	listSkillSelections,
	readSkillSelections,
	resolveDisabledSkills,
	SKILL_COLLECTION_IDS,
	SKILL_SELECTIONS_RELATIVE,
	type SkillSelectionConfig,
	validateDisabledCollections,
	writeSkillSelections,
} from "../lib/skill_selections.ts";

/** Resolve a collection id, or fail with the valid options. */
function requireCollectionIds(ids: readonly string[]): string[] {
	const unknown = ids.filter((id) => !SKILL_COLLECTION_IDS.includes(id));

	if (unknown.length > 0) {
		printError(`Unknown skill collection(s): ${unknown.join(", ")}`);
		console.log(`Valid ids: ${SKILL_COLLECTION_IDS.join(", ")}`);
		Deno.exit(1);
	}

	return [...ids];
}

/** Read the config, reporting a malformed file instead of throwing. */
async function readConfigOrExit(
	dotfilesDir: string,
): Promise<SkillSelectionConfig> {
	try {
		return await readSkillSelections(dotfilesDir);
	} catch (error) {
		printError(error instanceof Error ? error.message : String(error));
		Deno.exit(1);
	}
}

/** Persist a new toggle state, rewriting both the intent and derived files. */
async function writeConfig(
	dotfilesDir: string,
	disabledCollections: readonly string[],
) {
	const config = validateDisabledCollections([...disabledCollections]);
	await writeSkillSelections(dotfilesDir, config);
}

/**
 * Redeploy the agents group so the harness links match the new state.
 *
 * Tuckr only adds and updates links, so the group's post hook does the
 * stripping: it drops links for skills that are absent or disabled. Running
 * `tuckr set agents` is therefore what actually makes the change visible under
 * `~/.agents/skills`, `~/.codex/skills`, and `~/.claude/skills`.
 */
async function redeployAgentSkills(dotfilesDir: string) {
	printInfo("Redeploying the agents group");

	// Same repair as `dot rebuild` runs before its deploy: tuckr's linker skips
	// existing destinations, so links left dangling by a skill that moved inside
	// the repo would keep the group from converging on every toggle.
	const homeDir = Deno.env.get("HOME") ?? Deno.env.get("USERPROFILE");
	if (homeDir) {
		const prunedLinks = await repairAgentSkillDeployment(homeDir);
		if (prunedLinks.length > 0) {
			printInfo(`Pruned ${prunedLinks.length} stale managed skill link(s)`);
		}
	}

	// --only-files makes tuckr create missing parent directories, which its
	// default mode does not, so the link pass never fails on a freshly synced
	// skill or on the directories the post hook strips for disabled skills.
	const deployment = await runCommand(
		["tuckr", "set", "--only-files", "agents"],
		{
			cwd: dotfilesDir,
		},
	);

	if (!deployment.success) {
		printError(
			`Redeploy failed with exit code ${deployment.code}. Run \`dot reload\` to retry.`,
		);
		Deno.exit(1);
	}

	printSuccess("Agent skill links updated");
}

/** Report the collections this config disables, for confirmation output. */
function describeDisabled(ids: readonly string[]): string {
	return ids.length === 0 ? "none" : ids.join(", ");
}

export const skillsCommand = new Command()
	.description("Turn managed skill collections on and off")
	.command(
		"list",
		new Command()
			.description("Show every managed collection and its current state")
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();
				const config = await readConfigOrExit(dotfilesDir);

				printHeader("Managed skill collections");

				for (const state of await listSkillSelections(config, dotfilesDir)) {
					const status = state.enabled ? "enabled " : "disabled";
					const count = `${state.skills.length} skill(s)`;
					console.log(
						`  ${state.id.padEnd(12)} ${status}  ${
							count.padEnd(11)
						} ${state.summary}`,
					);
				}

				console.log("");
				printInfo(`Config: ${SKILL_SELECTIONS_RELATIVE}`);
				printInfo(
					`Disabled: ${describeDisabled(config.disabledCollections)}`,
				);
			}),
	)
	.command(
		"disable",
		new Command()
			.description(
				"Stop deploying one or more collections to the agent skill directories",
			)
			.arguments("<collections...:string>")
			.action(async (_opts, ...ids: string[]) => {
				const dotfilesDir = await resolveDotfilesDir();
				const targets = requireCollectionIds(ids);
				const config = await readConfigOrExit(dotfilesDir);
				const alreadyOff = targets.filter((id) =>
					isCollectionDisabled(config, id)
				);

				for (const id of alreadyOff) {
					printInfo(`${id} is already disabled`);
				}

				const newlyDisabled = targets.filter((id) =>
					!isCollectionDisabled(config, id)
				);

				if (newlyDisabled.length === 0) {
					printInfo("Nothing to change");
					return;
				}

				const disabled = [
					...config.disabledCollections,
					...newlyDisabled,
				];

				await writeConfig(dotfilesDir, disabled);
				printSuccess(`Disabled: ${newlyDisabled.join(", ")}`);

				await redeployAgentSkills(dotfilesDir);
			}),
	)
	.command(
		"enable",
		new Command()
			.description("Start deploying one or more collections again")
			.arguments("<collections...:string>")
			.action(async (_opts, ...ids: string[]) => {
				const dotfilesDir = await resolveDotfilesDir();
				const targets = requireCollectionIds(ids);
				const config = await readConfigOrExit(dotfilesDir);
				const alreadyOn = targets.filter((id) =>
					!isCollectionDisabled(config, id)
				);

				for (const id of alreadyOn) {
					printInfo(`${id} is already enabled`);
				}

				const newlyEnabled = targets.filter((id) =>
					isCollectionDisabled(config, id)
				);

				if (newlyEnabled.length === 0) {
					printInfo("Nothing to change");
					return;
				}

				const disabled = config.disabledCollections.filter(
					(id) => !newlyEnabled.includes(id),
				);

				await writeConfig(dotfilesDir, disabled);
				printSuccess(`Enabled: ${newlyEnabled.join(", ")}`);

				await redeployAgentSkills(dotfilesDir);
			}),
	)
	.command(
		"status",
		new Command()
			.description("Show which skills the toggle currently strips")
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();
				const config = await readConfigOrExit(dotfilesDir);

				printHeader("Disabled skill collections");
				console.log(`  ${describeDisabled(config.disabledCollections)}`);
				console.log("");

				printHeader("Skills stripped from the agent directories");
				const disabledSkills = await resolveDisabledSkills(
					config.disabledCollections,
					dotfilesDir,
				);

				if (disabledSkills.length === 0) {
					printInfo("None");
					return;
				}

				for (const name of disabledSkills) {
					console.log(`  ${name}`);
				}
			}),
	)
	.command(
		"apply",
		new Command()
			.description(
				"Re-read skills.toml, rewrite the derived fields, and redeploy",
			)
			.action(async () => {
				const dotfilesDir = await resolveDotfilesDir();

				// parseToml surfaces an invalid file here, before anything moves.
				const config = await readConfigOrExit(dotfilesDir);

				await writeConfig(dotfilesDir, config.disabledCollections);
				printSuccess(
					`Applied: ${describeDisabled(config.disabledCollections)}`,
				);

				await redeployAgentSkills(dotfilesDir);
			}),
	);
