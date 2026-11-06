import {
	installManagedSkillsFromCheckout,
	type ManagedSkillOptions,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

// ifiokjr/slopper is private, so the skill is read from its public npm
// package instead. The package releases with @slopperday/cli (monochange
// group `cli`), so the skill always documents a CLI version people can run.
//
// Every version npm records a gitHead for is pinnable; 0.1.8 was the one
// exception (published through pnpm, which stamps none), and slopper publishes
// with the npm CLI again from 0.1.9. Pin an exact version here if a release
// ever lands without one.
const SLOPPER_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	channel: "npm",
	displayName: "Slopper skill",
	manifestFile: ".slopper-source.json",
	repository: "@slopperday/skill",
	ref: "latest",
	skills: [
		{
			name: "slopper",
			sourcePath: "package",
		},
	],
	tempPrefix: "dot-slopper-",
	transactionLabel: "slopper",
	userAgent: "ifiokjr-dotfiles-slopper-skill-sync",
};

export const SLOPPER_SKILLS = SLOPPER_SOURCE.skills.map((skill) => skill.name);

/** Confirm every Slopper skill file resolves through each skill path. */
export async function verifySlopperSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
	opts: ManagedSkillOptions = {},
): Promise<string[]> {
	return await verifyManagedSkillDeployment(
		SLOPPER_SOURCE,
		dotfilesDir,
		homeDir,
		opts,
	);
}

/** Fetch the latest released Slopper skill and install it into the repository. */
export async function syncSlopperSkills(dotfilesDir: string) {
	return await syncManagedSkills(SLOPPER_SOURCE, dotfilesDir);
}

/** Replace the Slopper skill directory from an extracted package. */
export async function installSlopperSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		SLOPPER_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { SLOPPER_SOURCE };
