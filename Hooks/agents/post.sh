#!/usr/bin/env bash
set -euo pipefail

# post.sh - Agents configuration post-install hook
# Installs OpenCode plugins and tools

echo "Setting up AI agents configuration..."

MANAGED_PNPM_BIN="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm-global/node_modules/.bin"
if [ -d "$MANAGED_PNPM_BIN" ]; then
	export PATH="$MANAGED_PNPM_BIN:$PATH"
fi

# ---------------------------------------------------------------------------
# Verify the declaratively managed OCX installation
# ---------------------------------------------------------------------------
if command -v ocx &>/dev/null; then
	echo "OCX is installed through the managed pnpm project: $(which ocx)"
else
	echo "Warning: OCX is unavailable; run 'pnpm:global:sync' to install it"
fi

# ---------------------------------------------------------------------------
# Install OpenCode plugins
# ---------------------------------------------------------------------------
if command -v ocx &>/dev/null; then
	echo "Installing OpenCode plugins..."

	# Install worktree plugin for git worktree management
	# Docs: https://github.com/kdcokenny/opencode-worktree
	if ! ocx list | grep -q "kdco/worktree"; then
		echo "Installing opencode-worktree plugin..."
		ocx add kdco/worktree --from https://registry.kdco.dev || echo "Warning: Failed to install opencode-worktree"
	else
		echo "opencode-worktree already installed"
	fi
else
	echo "Warning: OCX not available, skipping OpenCode plugin installation"
	echo "After running 'pnpm:global:sync', install the plugin with:"
	echo "  ocx add kdco/worktree --from https://registry.kdco.dev"
fi

# ---------------------------------------------------------------------------
# Expose dotfiles-managed skills to Codex
# ---------------------------------------------------------------------------
# Codex scans ~/.codex/skills and ~/.agents/skills but skips symlinked files
# when collecting SKILL.md. Tuckr deploys managed skills as per-file symlinks,
# so Codex never sees them. Codex does follow directory symlinks, so link each
# managed skill directory straight to its repo copy, where the files are real.
# Existing entries (Codex-native skills) are never replaced.
DOTFILES_ROOT="$(cd "$(pwd)/../.." && pwd)"
MANAGED_SKILLS_DIR="$DOTFILES_ROOT/Configs/agents/.agents/skills"
CODEX_SKILLS_DIR="$HOME/.codex/skills"
if [ -d "$MANAGED_SKILLS_DIR" ] && [ -d "$CODEX_SKILLS_DIR" ]; then
	for skill_dir in "$MANAGED_SKILLS_DIR"/*/; do
		if [ ! -d "$skill_dir" ]; then
			continue
		fi
		skill_name="$(basename "$skill_dir")"
		target="$CODEX_SKILLS_DIR/$skill_name"
		if [ -e "$target" ] || [ -L "$target" ]; then
			continue
		fi
		ln -s "${skill_dir%/}" "$target"
		echo "Linked $skill_name into Codex skills"
	done
fi

echo "Agents configuration complete!"
