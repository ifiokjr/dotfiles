# Unified AI Agents Configuration

This directory centralizes configuration for all AI coding agents and tools.

## Supported Tools

| Tool         | Config Location       | Description                                 |
| ------------ | --------------------- | ------------------------------------------- |
| **OpenCode** | `~/.config/opencode/` | Universal AI agent with multi-model support |
| **Pi**       | `~/.pi/agent/`        | AI-powered development environment          |
| **Codex**    | `~/.codex/`           | OpenAI's Codex CLI tool                     |
| **Zed**      | `~/.config/zed/`      | AI-powered code editor with agent panel     |

## Configuration Files

### `agents.env.sh`

Environment variables that control agent behavior across all tools:

- `OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true` - Skip all permission prompts
- `OPENCODE_ALLOW_ALL_BASH=true` - Allow any bash command execution
- `OPENCODE_TRUSTED_DIRECTORIES` - Comma-separated list of auto-allowed paths

### `opencode/config.json`

OpenCode-specific configuration:

- Full file access permissions
- Trusted directory list
- Default model/provider settings
- UI confirmation preferences

### `AGENTS.md`

The canonical global agent instructions file. Every harness's global instruction file is a symlink to this file, so one edit updates all of them:

| Harness      | Global Instructions Location   |
| ------------ | ------------------------------ |
| **Pi**       | `~/.pi/agent/AGENTS.md`        |
| **Codex**    | `~/.codex/AGENTS.md`           |
| **Zed**      | `~/.config/zed/AGENTS.md`      |
| **OpenCode** | `~/.config/opencode/AGENTS.md` |

Edit the canonical file only — the harness locations are symlinks to it.

## Security Considerations

**WARNING**: The current configuration allows all AI agents full access to your filesystem and shell commands without confirmation prompts. This is intentional for development speed but be aware:

- Only use these settings on trusted, local development machines
- Review any generated code before committing
- Keep API keys in Monosecret + 1Password and run tools through `msr --reason "<why>" <command>` when they need secrets

## Environment Variable Precedence

1. Runtime environment variables (highest)
2. `~/.config/agents/agents.env.sh`
3. Tool-specific config files (e.g., `~/.config/opencode/config.json`)
4. Default behavior (lowest)

## OpenCode Plugins

OpenCode plugins are managed via [OCX](https://github.com/kdcokenny/ocx) (OpenCode eXtensions manager).

Installed plugins:

| Plugin                | Source          | Description                                    |
| --------------------- | --------------- | ---------------------------------------------- |
| **opencode-worktree** | `kdco/worktree` | Git worktrees with automatic terminal spawning |

### Installing Plugins

Plugins are automatically installed by the `Hooks/agents/post.sh` hook when the `agents` config group is deployed. To install manually:

```bash
# Install OCX (if not already installed)
npm install -g @kdcokenny/ocx

# Add a plugin
ocx add kdco/worktree --from https://registry.kdco.dev

# List installed plugins
ocx list
```

## Adding New AI Tools

When adding a new AI tool:

1. Create its config directory under `.config/<tool>/`
2. Add any environment variables to `agents.env.sh`
3. For OpenCode plugins, add installation to `Hooks/agents/post.sh`
4. To give it the global agent instructions, add a symlink at `Configs/agents/<harness-path>/<file>` pointing to `../.config/agents/AGENTS.md` (relative), using the harness's global file name and location
5. Document the tool in this README
6. Update the table above

## Related

- [Shell environment](../shell/.config/shell/env.sh) - Sources this configuration
- Pi config lives in user-managed `~/.pi/agent/settings.json`
- [Agents hook](../../../Hooks/agents/post.sh) - Post-install plugin setup
