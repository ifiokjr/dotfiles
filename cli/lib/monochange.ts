import {
	installManagedSkillsFromCheckout,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const MONOCHANGE_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	displayName: "monochange skills",
	manifestFile: ".monochange-source.json",
	repository: "monochange/monochange",
	ref: "main",
	skills: [
		{
			name: "monochange",
			sourcePath: "packages/monochange__skill",
		},
	],
	tempPrefix: "dot-monochange-",
	transactionLabel: "monochange",
	userAgent: "ifiokjr-dotfiles-monochange-skills-sync",
};

export const MONOCHANGE_SKILLS = MONOCHANGE_SOURCE.skills.map((skill) =>
	skill.name
);

/** Confirm every selected monochange file resolves through the shared skill path. */
export async function verifyMonochangeSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	return await verifyManagedSkillDeployment(
		MONOCHANGE_SOURCE,
		dotfilesDir,
		homeDir,
	);
}

/** Fetch the selected monochange skill and install it into the repository. */
export async function syncMonochangeSkills(dotfilesDir: string) {
	return await syncManagedSkills(MONOCHANGE_SOURCE, dotfilesDir);
}

/** Replace the selected monochange directories from an extracted checkout. */
export async function installMonochangeSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		MONOCHANGE_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { MONOCHANGE_SOURCE };
