import {
	installManagedSkillsFromCheckout,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const MATT_POCOCK_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	displayName: "Matt Pocock skills",
	manifestFile: ".matt-pocock-source.json",
	repository: "mattpocock/skills",
	ref: "main",
	skills: [
		{
			name: "diagnosing-bugs",
			sourcePath: "skills/engineering/diagnosing-bugs",
		},
		{
			name: "writing-for-agents",
			sourcePath: "skills/productivity/writing-for-agents",
		},
		{
			name: "handoff",
			sourcePath: "skills/productivity/handoff",
		},
		{
			name: "research",
			sourcePath: "skills/engineering/research",
		},
	],
	tempPrefix: "dot-matt-pocock-",
	transactionLabel: "matt-pocock",
	userAgent: "ifiokjr-dotfiles-matt-pocock-skills-sync",
};

export const MATT_POCOCK_SKILLS = MATT_POCOCK_SOURCE.skills.map((skill) =>
	skill.name
);

/** Confirm every selected source file resolves through the shared skill path. */
export async function verifyMattPocockSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	return await verifyManagedSkillDeployment(
		MATT_POCOCK_SOURCE,
		dotfilesDir,
		homeDir,
	);
}

/** Fetch the selected skills and install them into the repository. */
export async function syncMattPocockSkills(dotfilesDir: string) {
	return await syncManagedSkills(MATT_POCOCK_SOURCE, dotfilesDir);
}

/** Replace the selected directories from an extracted checkout. */
export async function installMattPocockSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		MATT_POCOCK_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { MATT_POCOCK_SOURCE };
