import {
	installManagedSkillsFromCheckout,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const PSTACK_SOURCE: ManagedSkillSource = {
	displayName: "P-Stack",
	manifestFile: ".pstack-source.json",
	repository: "cursor/plugins",
	ref: "main",
	skills: [
		"principle-prove-it-works",
		"principle-type-system-discipline",
		"principle-fix-root-causes",
		"blast-radius",
		"how",
		"principle-laziness-protocol",
		"recall",
		"principle-boundary-discipline",
		"technical-writing",
		"unslop",
		"architect",
		"principle-model-the-domain",
		"principle-minimize-reader-load",
		"principle-sequence-verifiable-units",
		"principle-subtract-before-you-add",
		"interrogate",
		"why",
		"create-verification-skill",
		"show-me-your-work",
		"principle-make-operations-idempotent",
	].map((name) => ({ name, sourcePath: `pstack/skills/${name}` })),
	tempPrefix: "dot-pstack-",
	transactionLabel: "pstack",
	userAgent: "ifiokjr-dotfiles-pstack-sync",
};

export const PSTACK_SKILLS = PSTACK_SOURCE.skills.map((skill) => skill.name);

/** Confirm every P-Stack source file resolves through the shared skill path. */
export async function verifyPstackSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
): Promise<string[]> {
	return await verifyManagedSkillDeployment(
		PSTACK_SOURCE,
		dotfilesDir,
		homeDir,
	);
}

/** Fetch the selected P-Stack skills and install them into the repository. */
export async function syncPstackSkills(dotfilesDir: string) {
	return await syncManagedSkills(PSTACK_SOURCE, dotfilesDir);
}

/** Replace the selected P-Stack directories from an extracted checkout. */
export async function installPstackSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		PSTACK_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { PSTACK_SOURCE };
