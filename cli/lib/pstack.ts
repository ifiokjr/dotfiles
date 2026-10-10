import {
	installManagedSkillsFromCheckout,
	type ManagedSkillOptions,
	type ManagedSkillSource,
	syncManagedSkills,
	verifyManagedSkillDeployment,
} from "./managed_skills.ts";

const PSTACK_SKILLS_DIRECTORY = "pstack/skills";

/**
 * The skills upstream shipped when the collection switched to discovery.
 *
 * Each sync supersedes this list with what `pstack/skills` actually contains,
 * but it seeds the source's ownership before a first manifest exists and
 * keeps conflict checks working if the manifest goes missing. The names are
 * pre-sorted so the manifest stays stable across runs.
 */
const PSTACK_SKILL_NAMES = [
	"architect",
	"arena",
	"automate-me",
	"benchmark-checklist",
	"blast-radius",
	"bro",
	"correct",
	"create-verification-skill",
	"figure-it-out",
	"how",
	"interrogate",
	"maintain-verification-skill",
	"make-bot-ui",
	"no-comments",
	"poteto-help",
	"poteto-mode",
	"principle-attack-the-premise",
	"principle-boundary-discipline",
	"principle-build-the-lever",
	"principle-encode-lessons-in-structure",
	"principle-exhaust-the-design-space",
	"principle-experience-first",
	"principle-explain-the-number",
	"principle-fix-root-causes",
	"principle-foundational-thinking",
	"principle-guard-the-context-window",
	"principle-laziness-protocol",
	"principle-make-operations-idempotent",
	"principle-migrate-callers-then-delete-legacy-apis",
	"principle-minimize-reader-load",
	"principle-model-the-domain",
	"principle-never-block-on-the-human",
	"principle-outcome-oriented-execution",
	"principle-prove-it-works",
	"principle-redesign-from-first-principles",
	"principle-separate-before-serializing-shared-state",
	"principle-sequence-verifiable-units",
	"principle-subtract-before-you-add",
	"principle-test-behavior-not-implementation",
	"principle-type-system-discipline",
	"recall",
	"reflect",
	"setup-pstack",
	"show-me-your-work",
	"swarm",
	"tdd",
	"teach",
	"technical-writing",
	"typescript-best-practices",
	"unslop",
	"why",
];

const PSTACK_SOURCE: ManagedSkillSource = {
	displayName: "P-Stack",
	manifestFile: ".pstack-source.json",
	repository: "cursor/plugins",
	ref: "main",
	skills: PSTACK_SKILL_NAMES.map((name) => ({
		name,
		sourcePath: `${PSTACK_SKILLS_DIRECTORY}/${name}`,
	})),
	skillsDirectory: PSTACK_SKILLS_DIRECTORY,
	tempPrefix: "dot-pstack-",
	transactionLabel: "pstack",
	userAgent: "ifiokjr-dotfiles-pstack-sync",
};

export const PSTACK_SKILLS = PSTACK_SOURCE.skills.map((skill) => skill.name);

/** Confirm every P-Stack source file resolves through the shared skill path. */
export async function verifyPstackSkillDeployment(
	dotfilesDir: string,
	homeDir: string,
	opts: ManagedSkillOptions = {},
): Promise<string[]> {
	return await verifyManagedSkillDeployment(
		PSTACK_SOURCE,
		dotfilesDir,
		homeDir,
		opts,
	);
}

/**
 * Fetch every P-Stack skill upstream ships and install them into the
 * repository.
 *
 * The source tracks `pstack/skills` as a directory, so each sync mirrors
 * upstream exactly: skills Poteto added are discovered, skills she removed
 * are dropped, and the manifest records what this sync installed.
 */
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
