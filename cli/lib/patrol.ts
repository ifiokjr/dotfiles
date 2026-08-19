import {
	installManagedSkillsFromCheckout,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const PATROL_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	displayName: "Patrol skills",
	manifestFile: ".patrol-source.json",
	repository: "leancodepl/patrol",
	ref: "master",
	skills: ["patrol-setup", "patrol-write-test"].map((name) => ({
		name,
		sourcePath: `skills/${name}`,
	})),
	tempPrefix: "dot-patrol-",
	transactionLabel: "patrol",
	userAgent: "ifiokjr-dotfiles-patrol-skills-sync",
};

export const PATROL_SKILLS = PATROL_SOURCE.skills.map((skill) => skill.name);

/** Confirm every selected Patrol file resolves through each skill path. */
export async function verifyPatrolSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	return await verifyManagedSkillDeployment(
		PATROL_SOURCE,
		dotfilesDir,
		homeDir,
	);
}

/** Fetch the selected Patrol skills and install them into the repository. */
export async function syncPatrolSkills(dotfilesDir: string) {
	return await syncManagedSkills(PATROL_SOURCE, dotfilesDir);
}

/** Replace the selected Patrol directories from an extracted checkout. */
export async function installPatrolSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		PATROL_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { PATROL_SOURCE };
