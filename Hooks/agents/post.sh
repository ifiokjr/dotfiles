#!/usr/bin/env bash
set -euo pipefail

# post.sh - Agents configuration post-install hook
# Links managed skill directories into harness-specific skill locations

echo "Setting up AI agents configuration..."

DOTFILES_ROOT="$(cd "$(pwd)/../.." && pwd)"
MANAGED_SKILLS_DIR="$DOTFILES_ROOT/Configs/agents/.agents/skills"

# ---------------------------------------------------------------------------
# Expose dotfiles-managed skills to Codex
# ---------------------------------------------------------------------------
# Codex scans ~/.codex/skills and ~/.agents/skills but skips symlinked files
# when collecting SKILL.md. Tuckr deploys managed skills as per-file symlinks,
# so Codex never sees them. Codex does follow directory symlinks, so link each
# managed skill directory straight to its repo copy, where the files are real.
# Existing entries (Codex-native skills) are never replaced.
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

# ---------------------------------------------------------------------------
# Expose dotfiles-managed skills to Claude Code
# ---------------------------------------------------------------------------
# Claude Code reads skills from ~/.claude/skills (plus project .claude/skills,
# plugins, and --add-dir directories). It does not read the shared
# ~/.agents/skills path that OpenCode, Cursor, Gemini CLI, and Zed consume, so
# the managed skills have to be mirrored here too.
#
# Claude follows a symlinked skill directory, and it follows a symlinked
# SKILL.md inside a real directory, which is the shape Tuckr leaves behind in
# ~/.agents/skills. Pointing at that deployed path rather than at the repo
# keeps this working when the repo moves, and covers skills that arrive through
# `dot rebuild --update` from external sources instead of being committed here.
#
# Only managed skills are linked. Claude's own `synced` directory, which holds
# account-synced skills, is left untouched, and an existing entry is never
# replaced so a locally installed skill of the same name wins.
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
DEPLOYED_SKILLS_DIR="$HOME/.agents/skills"
if [ -d "$DEPLOYED_SKILLS_DIR" ] && [ -d "$CLAUDE_SKILLS_DIR" ]; then
	for skill_dir in "$DEPLOYED_SKILLS_DIR"/*/; do
		skill_name="$(basename "$skill_dir")"
		# Skip source manifests and other dotfiles in the skills directory.
		case "$skill_name" in
		.*) continue ;;
		esac
		# A skill without SKILL.md is not a skill; skip rather than link it.
		if [ ! -f "$skill_dir/SKILL.md" ]; then
			continue
		fi
		target="$CLAUDE_SKILLS_DIR/$skill_name"
		if [ -e "$target" ] || [ -L "$target" ]; then
			continue
		fi
		ln -s "${skill_dir%/}" "$target"
		echo "Linked $skill_name into Claude skills"
	done
fi

echo "Agents configuration complete!"
