import {
	installManagedSkillsFromCheckout,
	type ManagedSkillOptions,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const SECURITY_AUDIT_SOURCE: ManagedSkillSource = {
	compatibilityRoots: [".pi/agent/skills"],
	displayName: "Cloudflare security-audit skills",
	manifestFile: ".security-audit-source.json",
	repository: "cloudflare/security-audit-skill",
	ref: "main",
	skills: [
		{
			name: "security-audit",
			sourcePath: "skills/security-audit",
		},
	],
	tempPrefix: "dot-security-audit-",
	transactionLabel: "security-audit",
	userAgent: "ifiokjr-dotfiles-security-audit-skills-sync",
};

export const SECURITY_AUDIT_SKILLS = SECURITY_AUDIT_SOURCE.skills.map((
	skill,
) => skill.name);

/** Confirm every selected security-audit file resolves through each skill path. */
export async function verifySecurityAuditSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
	opts: ManagedSkillOptions = {},
): Promise<string[]> {
	return await verifyManagedSkillDeployment(
		SECURITY_AUDIT_SOURCE,
		dotfilesDir,
		homeDir,
		opts,
	);
}

/** Fetch the selected security-audit skill and install it into the repository. */
export async function syncSecurityAuditSkills(dotfilesDir: string) {
	return await syncManagedSkills(SECURITY_AUDIT_SOURCE, dotfilesDir);
}

/** Replace the selected security-audit directories from an extracted checkout. */
export async function installSecurityAuditSkillsFromCheckout(
	checkoutDir: string,
	dotfilesDir: string,
	resolvedSha: string,
): Promise<void> {
	await installManagedSkillsFromCheckout(
		SECURITY_AUDIT_SOURCE,
		checkoutDir,
		dotfilesDir,
		resolvedSha,
	);
}

export { SECURITY_AUDIT_SOURCE };
