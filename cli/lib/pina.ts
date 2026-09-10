import {
	installManagedSkillsFromCheckout,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const PINA_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	displayName: "pina skills",
	manifestFile: ".pina-source.json",
	repository: "pina-rs/pina",
	ref: "main",
	skills: [
		{
			name: "pina",
			sourcePath: "packages/pina__skill",
		},
	],
	tempPrefix: "dot-pina-",
	transactionLabel: "pina",
	userAgent: "ifiokjr-dotfiles-pina-skills-sync",
};

export const PINA_SKILLS = PINA_SOURCE.skills.map((skill) => skill.name);

/** Confirm every selected pina file resolves through the shared skill path. */
export async function verifyPinaSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	return await verifyManagedSkillDeployment(PINA_SOURCE, dotfilesDir, homeDir);
}

/** Fetch the selected pina skill and install it into the repository. */
export async function syncPinaSkills(dotfilesDir: string) {
	return await syncManagedSkills(PINA_SOURCE, dotfilesDir);
}

/** Replace the selected pina directories from an extracted checkout. */
export async function installPinaSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		PINA_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { PINA_SOURCE };
