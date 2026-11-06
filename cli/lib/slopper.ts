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
// Pin to the newest version npm records a gitHead for: 0.1.8 was published
// through monochange 0.21, which hands pnpm-workspace packages to `pnpm
// publish`, and pnpm 11+ no longer stamps gitHead on published packages. The
// sync refuses unpinned npm versions by design, so "latest" would fail every
// update until monochange publishes a gitHead-bearing release — flip this
// back to "latest" once one lands.
const SLOPPER_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	channel: "npm",
	displayName: "Slopper skill",
	manifestFile: ".slopper-source.json",
	repository: "@slopperday/skill",
	ref: "0.1.7",
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
