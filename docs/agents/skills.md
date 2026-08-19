# Skills Usage

Use skills when the user explicitly names one or when the task clearly matches a listed skill.

## Dotfiles-Managed Skills

Reusable global skills are tracked in `Configs/agents/.agents/skills/<skill-name>` and deployed to `~/.agents/skills/<skill-name>` by the `agents` Tuckr group. When installing a reusable skill, copy it into this directory and replace the local install with a symlink to the dotfiles-managed path so it can be reused across machines.

Current dotfiles-managed skills:

- `devenv`: Path: `Configs/agents/.agents/skills/devenv/SKILL.md`
- `dotfiles`: Path: `Configs/agents/.agents/skills/dotfiles/SKILL.md`
- `git-workflow`: Path: `Configs/agents/.agents/skills/git-workflow/SKILL.md`
- `playwright-cli`: Path: `Configs/agents/.agents/skills/playwright-cli/SKILL.md`

Managed P-Stack selection, in priority order:

1. `principle-prove-it-works`: Path: `Configs/agents/.agents/skills/principle-prove-it-works/SKILL.md`
2. `principle-type-system-discipline`: Path: `Configs/agents/.agents/skills/principle-type-system-discipline/SKILL.md`
3. `principle-fix-root-causes`: Path: `Configs/agents/.agents/skills/principle-fix-root-causes/SKILL.md`
4. `blast-radius`: Path: `Configs/agents/.agents/skills/blast-radius/SKILL.md`
5. `how`: Path: `Configs/agents/.agents/skills/how/SKILL.md`
6. `principle-laziness-protocol`: Path: `Configs/agents/.agents/skills/principle-laziness-protocol/SKILL.md`
7. `recall`: Path: `Configs/agents/.agents/skills/recall/SKILL.md`
8. `principle-boundary-discipline`: Path: `Configs/agents/.agents/skills/principle-boundary-discipline/SKILL.md`
9. `technical-writing`: Path: `Configs/agents/.agents/skills/technical-writing/SKILL.md`
10. `unslop`: Path: `Configs/agents/.agents/skills/unslop/SKILL.md`
11. `architect`: Path: `Configs/agents/.agents/skills/architect/SKILL.md`
12. `principle-model-the-domain`: Path: `Configs/agents/.agents/skills/principle-model-the-domain/SKILL.md`
13. `principle-minimize-reader-load`: Path: `Configs/agents/.agents/skills/principle-minimize-reader-load/SKILL.md`
14. `principle-sequence-verifiable-units`: Path: `Configs/agents/.agents/skills/principle-sequence-verifiable-units/SKILL.md`
15. `principle-subtract-before-you-add`: Path: `Configs/agents/.agents/skills/principle-subtract-before-you-add/SKILL.md`
16. `interrogate`: Path: `Configs/agents/.agents/skills/interrogate/SKILL.md`
17. `why`: Path: `Configs/agents/.agents/skills/why/SKILL.md`
18. `create-verification-skill`: Path: `Configs/agents/.agents/skills/create-verification-skill/SKILL.md`
19. `show-me-your-work`: Path: `Configs/agents/.agents/skills/show-me-your-work/SKILL.md`
20. `principle-make-operations-idempotent`: Path: `Configs/agents/.agents/skills/principle-make-operations-idempotent/SKILL.md`

The P-Stack selection comes from [`cursor/plugins`](https://github.com/cursor/plugins/tree/main/pstack/skills). Its resolved source commit and exact directory list live in `Configs/agents/.agents/skills/.pstack-source.json`.

Managed Matt Pocock selection, in priority order:

1. `diagnosing-bugs`: Path: `Configs/agents/.agents/skills/diagnosing-bugs/SKILL.md`
2. `writing-for-agents`: Path: `Configs/agents/.agents/skills/writing-for-agents/SKILL.md`
3. `handoff`: Path: `Configs/agents/.agents/skills/handoff/SKILL.md`
4. `research`: Path: `Configs/agents/.agents/skills/research/SKILL.md`

This selection comes from [`mattpocock/skills`](https://github.com/mattpocock/skills). Its resolved source commit and exact directory list live in `Configs/agents/.agents/skills/.matt-pocock-source.json`.

`dot rebuild --update` refreshes both managed selections from their latest `main` commits, updates both source manifests, and runs `tuckr add agents` once so new or removed skill files are reflected under `~/.agents/skills`. The Matt Pocock selection also has tracked compatibility links under `Configs/agents/.pi/agent/skills`, which expose the same files to Pi without duplicating them. Codex, Cursor, Gemini CLI, OpenCode, and Zed consume the shared path directly.

Each source update is atomic: an incomplete download or missing `SKILL.md` leaves that installed selection unchanged. A sync failure stops the update instead of silently continuing with stale skills. Duplicate target names across the selections are rejected before either source is updated, and deployment verification checks every source file through both the shared and Pi paths.

### Coexistence Boundaries

The selected collections have no skill-name collisions. Related skills are intentionally separated by workflow:

- `diagnosing-bugs` owns the end-to-end debugging workflow; P-Stack's `principle-fix-root-causes` and `principle-prove-it-works` are manually invoked guardrails.
- `writing-for-agents` is for agent-consumed instructions such as `AGENTS.md` and skills; `technical-writing` is for general technical prose.
- `handoff` writes forward-looking continuation state; `recall` reconstructs historical work from repository evidence.
- `research` investigates external topics and primary sources; `why` traces design rationale inside a repository and its connected history.

## Available Skills

- `dotfiles`: dotfiles-specific Monosecret + 1Password workflow. Path: `~/.agents/skills/dotfiles/SKILL.md`
- `backblaze-upload`: upload files to Backblaze B2 and generate links. Path: `/Users/ifiokjr/.codex/skills/backblaze-upload/SKILL.md`
- `figma`: use Figma MCP for node context/screenshots/variables/design-to-code. Path: `/Users/ifiokjr/.codex/skills/figma/SKILL.md`
- `gh-address-comments`: address PR comments via `gh`. Path: `/Users/ifiokjr/.codex/skills/gh-address-comments/SKILL.md`
- `gh-fix-ci`: inspect/fix failing GitHub Actions checks (with explicit approval before implementation). Path: `/Users/ifiokjr/.codex/skills/gh-fix-ci/SKILL.md`
- `playwright`: browser automation and UI flow checks. Path: `/Users/ifiokjr/.codex/skills/playwright/SKILL.md`
- `yeet`: stage, commit, push, and open PR in one flow when explicitly requested. Path: `/Users/ifiokjr/.codex/skills/yeet/SKILL.md`
- `skill-creator`: create/update skills. Path: `/Users/ifiokjr/.codex/skills/.system/skill-creator/SKILL.md`
- `skill-installer`: install curated or repo-hosted skills. Path: `/Users/ifiokjr/.codex/skills/.system/skill-installer/SKILL.md`

## How To Apply Skills

- Read the chosen `SKILL.md` first; only load what is needed.
- Resolve relative paths from the skill directory before searching elsewhere.
- Reuse bundled scripts/templates/assets when available.
- If multiple skills match, use the minimum set and state order.
- If a skill is missing/unreadable, state that and continue with fallback.
- Do not carry skills across turns unless re-mentioned.
