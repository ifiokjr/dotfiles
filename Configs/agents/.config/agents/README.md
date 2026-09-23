# Unified AI Agents Configuration

This directory centralizes configuration for all AI coding agents and tools.

## Supported Tools

| Tool            | Config Location       | Description                                 |
| --------------- | --------------------- | ------------------------------------------- |
| **OpenCode**    | `~/.config/opencode/` | Universal AI agent with multi-model support |
| **Claude Code** | `~/.claude/`          | Anthropic's terminal coding agent           |
| **Pi**          | `~/.pi/agent/`        | AI-powered development environment          |
| **Codex**       | `~/.codex/`           | OpenAI's Codex CLI tool                     |
| **Zed**         | `~/.config/zed/`      | AI-powered code editor with agent panel     |

## Configuration Files

### `agents.env.sh`

Environment variables that control agent behavior across all tools. OpenCode exposes no environment variable for permission prompts or trusted directories, so its settings live in `opencode/opencode.json` instead of here.

### `opencode/opencode.json`

OpenCode configuration, used by the `opencode` command:

- Global `permission` rules, with `"*"` set to `allow` for unrestricted access
- `external_directory` set to `"*": "allow"`, which is what actually governs file and shell access outside the working directory
- Default model selection

The file must be named `opencode.json`. An earlier revision used `config.json`, which OpenCode silently ignores: `opencode debug config` reports only the config directories in that case, so every permission in it was inert and sessions ran on the default ask-based rules. Keep the name `opencode.json`.

OpenCode validates this file strictly and rejects unknown keys, so every key must exist in the [config schema](https://opencode.ai/config.json).

### `opencode-v2/opencode.json`

Secondary OpenCode configuration, used by the `opencode2` command:

- `permissions` as an ordered array of `{ action, resource, effect }` rules
- Default model selection

Both configs are read by the same OpenCode binary and both accept the singular `permission` map, so this directory is no longer required to keep the two versions apart. It is kept because the `opencode2` wrapper still points `OPENCODE_CONFIG_DIR` here, and the array form is the shape the newer `permissions` key takes.

There is no published schema for the array form, so this file omits `$schema` — pointing it at the map schema would flag `permissions` as invalid.

### `claude/settings.json`

Claude Code's user settings, deployed to `~/.claude/settings.json`:

- `permissions.defaultMode` set to `bypassPermissions`, so sessions skip permission prompts instead of stopping to ask
- `skipDangerousModePermissionPrompt`, which suppresses the one-time dialog that otherwise has to be accepted before the mode takes effect

`bypassPermissions` is honored only from user or managed settings. A project `.claude/settings.json` that sets it is ignored, so this must stay at the user level. Claude Code reads this file without rewriting it, which is what makes a symlinked copy safe here.

### `AGENTS.md`

The canonical global agent instructions file. Every harness's global instruction file is a symlink to this file, so one edit updates all of them:

| Harness         | Global Instructions Location   |
| --------------- | ------------------------------ |
| **Pi**          | `~/.pi/agent/AGENTS.md`        |
| **Codex**       | `~/.codex/AGENTS.md`           |
| **Zed**         | `~/.config/zed/AGENTS.md`      |
| **OpenCode**    | `~/.config/opencode/AGENTS.md` |
| **Claude Code** | `~/.claude/CLAUDE.md`          |

Edit the canonical file only — the harness locations are symlinks to it.

Claude Code is the one harness whose global file is not named `AGENTS.md`. It reads `AGENTS.md` for _project_ instructions, one found by walking up from the working directory, but at the _user_ level it reads `~/.claude/CLAUDE.md` and ignores `~/.claude/AGENTS.md`. Both were confirmed against Claude Code 2.1.280 by planting a token in each file and asking for it: a project `AGENTS.md` was read, `~/.claude/AGENTS.md` was not, and a symlinked `~/.claude/CLAUDE.md` was. The user-level and project-level files load together, so the shared instructions do not suppress a repository's own `AGENTS.md`.

Reading a project `AGENTS.md` requires Claude Code v2.1.277 or later, and is skipped when a `CLAUDE.md` or `CLAUDE.local.md` exists in the working directory or above it, unless the `Project instructions` setting is changed to `claude-md-and-agents-md`.

### Skills

Managed skills live under `Configs/agents/.agents/skills/` and deploy to `~/.agents/skills/`. That shared path is read directly by OpenCode, Cursor, Gemini CLI, and Zed. Two harnesses do not read it and need links created by `Hooks/agents/post.sh`:

- **Codex** skips symlinked `SKILL.md` files, so each managed skill directory is linked into `~/.codex/skills` pointing at the repo copy, where files are real.
- **Claude Code** reads only `~/.claude/skills`, project `.claude/skills`, plugin skills, and directories passed with `--add-dir`. It does not read `~/.agents/skills`, confirmed on 2.1.280 by placing a probe skill there and finding it invisible while the same skill in `~/.claude/skills` was found. Each managed skill directory is linked into `~/.claude/skills` pointing at the deployed `~/.agents/skills` path, which covers externally synced skills as well as committed ones.

The link step skips dotfiles such as `.mdt-source.json`, skips directories with no `SKILL.md`, and never replaces an existing entry, so a locally installed skill of the same name wins and Claude's own `synced` directory is untouched.

A skill whose frontmatter sets `disable-model-invocation: true` is deliberately invisible to the model and can only be run as `/name`. That is expected for the 21 managed skills that use it, not a linking failure.

The shared code-quality standard applies across projects and harnesses, including Codex. It requires idiomatic designs with explicit ownership, meaningful verification, root-cause fixes, and an honest account of remaining limits. Project-specific instructions add their own language and framework conventions.

## Security Considerations

**WARNING**: The current configuration allows all AI agents full access to your filesystem and shell commands without confirmation prompts. This is intentional for development speed but be aware:

- Only use these settings on trusted, local development machines
- Review any generated code before committing
- Keep API keys in Monosecret + 1Password and run tools through `msr --reason "<why>" <command>` when they need secrets

## Environment Variable Precedence

1. Runtime environment variables (highest)
2. `~/.config/agents/agents.env.sh`
3. Tool-specific config files (e.g., `~/.config/opencode/opencode.json`)
4. Default behavior (lowest)

## OpenCode Integration

OpenCode reads global instructions from `~/.config/opencode/AGENTS.md`, which Tuckr deploys as a symlink to the canonical `Configs/agents/.config/agents/AGENTS.md` shared by every harness. Git workflows, including worktree rules, are covered by those house rules together with the `git-workflow` skill under `Configs/agents/.agents/skills/git-workflow`.

No OpenCode plugins are installed; the `kdco/worktree` plugin was removed in favor of the AGENTS.md guidance above.

## Adding New AI Tools

When adding a new AI tool:

1. Create its config directory under `.config/<tool>/`
2. Add any environment variables to `agents.env.sh`
3. To give it the global agent instructions, add a symlink at `Configs/agents/<harness-path>/<file>` pointing to `../.config/agents/AGENTS.md` (relative), using the harness's global file name and location
4. Document the tool in this README
5. Update the table above

## Related

- [Shell environment](../shell/.config/shell/env.sh) - Sources this configuration
- Pi config lives in user-managed `~/.pi/agent/settings.json`
- [Agents hook](../../../Hooks/agents/post.sh) - Post-install skill linking
