#!/usr/bin/env bash
set -euo pipefail

# post.sh - Agents configuration post-install hook
# Links managed skill directories into harness-specific skill locations

echo "Setting up AI agents configuration..."

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
