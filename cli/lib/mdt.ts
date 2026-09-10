import {
	installManagedSkillsFromCheckout,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const MDT_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	displayName: "mdt skills",
	manifestFile: ".mdt-source.json",
	repository: "ifiokjr/mdt",
	ref: "main",
	skills: [
		{
			name: "mdt",
			sourcePath: "packages/m-d-t__skills/skills/mdt",
		},
	],
	tempPrefix: "dot-mdt-",
	transactionLabel: "mdt",
	userAgent: "ifiokjr-dotfiles-mdt-skills-sync",
};

export const MDT_SKILLS = MDT_SOURCE.skills.map((skill) => skill.name);

/** Confirm every selected mdt file resolves through the shared skill path. */
export async function verifyMdtSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	return await verifyManagedSkillDeployment(MDT_SOURCE, dotfilesDir, homeDir);
}

/** Fetch the selected mdt skill and install it into the repository. */
export async function syncMdtSkills(dotfilesDir: string) {
	return await syncManagedSkills(MDT_SOURCE, dotfilesDir);
}

/** Replace the selected mdt directories from an extracted checkout. */
export async function installMdtSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		MDT_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { MDT_SOURCE };
