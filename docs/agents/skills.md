# Skills Usage

Use skills when the user explicitly names one or when the task clearly matches a listed skill.

## Available Skills

- `dotfiles-secretspec`: dotfiles-specific SecretSpec + 1Password workflow. Path: `.agents/skills/dotfiles-secretspec/SKILL.md`
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
