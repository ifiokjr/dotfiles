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

# ---------------------------------------------------------------------------
# Seed the OpenCode credential store with the Z.AI (GLM) key
# ---------------------------------------------------------------------------
# T3 Code spawns `opencode` itself, in a process that never sources a shell
# rc file, so an exported ZHIPU_API_KEY is invisible to it. OpenCode also
# accepts credentials from ~/.local/share/opencode/auth.json, which is
# environment-independent, so seed that instead.
#
# Source is the same Keychain item Codex uses for its ZAI provider; the value
# never touches the repo. Only zai-coding-plan is seeded: it serves the GLM
# Coding Plan models (zai-coding-plan/glm-5.3) that the key is entitled to,
# while the non-plan `zai` endpoint answers 429 with it.
#
# Best-effort: a missing Keychain item (fresh machine, Linux) must not fail
# the hook, and an existing entry is never overwritten.
if [ "$(uname -s)" = "Darwin" ] && command -v jq >/dev/null 2>&1; then
	OPENCODE_AUTH="$HOME/.local/share/opencode/auth.json"
	zai_key=$(/usr/bin/security find-generic-password \
		-a "${USER}" -s codex-zai-api-key -w 2>/dev/null || true)
	if [ -n "$zai_key" ]; then
		mkdir -p "$(dirname "$OPENCODE_AUTH")"
		if [ ! -f "$OPENCODE_AUTH" ]; then
			printf '{}' >"$OPENCODE_AUTH"
		fi
		# chmod before writing so the key is never briefly world-readable.
		chmod 600 "$OPENCODE_AUTH"
		if ! jq -e '.keys | index("zai-coding-plan")' "$OPENCODE_AUTH" >/dev/null 2>&1; then
			if jq --arg key "$zai_key" \
				'.["zai-coding-plan"] = {type: "api", key: $key}' \
				"$OPENCODE_AUTH" >"$OPENCODE_AUTH.tmp" 2>/dev/null; then
				mv "$OPENCODE_AUTH.tmp" "$OPENCODE_AUTH"
				chmod 600 "$OPENCODE_AUTH"
				echo "Seeded zai-coding-plan credential for OpenCode"
			else
				rm -f "$OPENCODE_AUTH.tmp"
			fi
		fi
	fi
	unset zai_key
fi

echo "Agents configuration complete!"
