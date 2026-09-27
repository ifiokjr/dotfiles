#!/usr/bin/env bash
set -euo pipefail

# post.sh - Agents configuration post-install hook
# Links managed skill directories into harness-specific skill locations

echo "Setting up AI agents configuration..."

# Resolve the repo from this script's own location (Hooks/agents/post.sh) rather
# than from the working directory. Tuckr runs hooks with the repo root as the
# working directory while a manual run from this directory would differ, and the
# earlier `$(pwd)/../..` form resolved to the home directory's parent under
# Tuckr, silently pointing every path below at the wrong place.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANAGED_SKILLS_DIR="$DOTFILES_ROOT/Configs/agents/.agents/skills"
CODEX_SKILLS_DIR="$HOME/.codex/skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
DEPLOYED_SKILLS_DIR="$HOME/.agents/skills"
PI_SKILLS_DIR="$HOME/.pi/agent/skills"

# ---------------------------------------------------------------------------
# Disabled skill collections
# ---------------------------------------------------------------------------
# `dot skills disable` writes the resolved skill names to .disabled-skills
# beside the other managed-skill metadata. Skills named there stay in the repo
# but are kept out of every harness directory below, including the deployed
# ~/.agents/skills tree that Tuckr itself populates. Reading a plain list rather
# than the TOML intent file keeps this hook free of a TOML parser.

DISABLED_SKILLS_LIST="$MANAGED_SKILLS_DIR/.disabled-skills"

# True when a skill name appears in the disabled list.
#
# A missing list means nothing is disabled, which is the correct reading for a
# repo that never used the toggle. When the managed skills directory itself is
# missing the path is wrong rather than empty, and saying so beats silently
# deciding that every disabled skill is actually enabled.
skill_is_disabled() {
	local name="$1" line
	if [ ! -d "$MANAGED_SKILLS_DIR" ]; then
		echo "Cannot resolve the managed skills directory: $MANAGED_SKILLS_DIR" >&2
		exit 1
	fi
	[ -f "$DISABLED_SKILLS_LIST" ] || return 1
	while IFS= read -r line; do
		[ "$line" = "$name" ] && return 0
	done <"$DISABLED_SKILLS_LIST"
	return 1
}

# Remove a disabled skill's entry from a harness directory.
#
# Removal is driven only by the explicit disabled list, never inferred from link
# state: an earlier version also pruned directories whose links had gone
# dangling, and that deleted healthy skills whenever it ran mid-deploy, before
# Tuckr had finished repointing their links.
#
# Even listed names are removed only when the entry proves it came from this
# repo, so a locally installed skill that happens to share a name survives. A
# Tuckr-deployed skill is a real directory holding per-file symlinks into the
# managed roots, which is what the ownership check looks for.
remove_disabled_skill_links() {
	local skills_dir="$1" entry name
	[ -d "$skills_dir" ] || return 0
	[ -f "$DISABLED_SKILLS_LIST" ] || return 0
	for entry in "$skills_dir"/*; do
		[ -e "$entry" ] || [ -L "$entry" ] || continue
		name="$(basename "$entry")"
		skill_is_disabled "$name" || continue
		if ! entry_is_managed_skill "$entry"; then
			echo "Skipped disabled skill $name in $skills_dir: not dotfiles-managed"
			continue
		fi
		rm -rf "$entry"
		echo "Disabled skill $name removed from $skills_dir"
	done
}

# True when a harness entry points at this repo's managed skills.
#
# Tuckr points its links at its own checkout location, which is a symlink to
# this repo and not necessarily the path this hook sees, so a literal prefix
# match against the managed roots misses real deployments. Match on the
# repo-specific path suffix instead, the same way the OpenCode cleanup in
# pre.sh does.
entry_is_managed_skill() {
	local entry="$1" target inner
	if [ -L "$entry" ]; then
		target="$(readlink "$entry")"
		case "$target" in
		*/Configs/agents/.agents/skills/* | */Configs/agents/.pi/agent/skills/*)
			return 0
			;;
		*) return 1 ;;
		esac
	fi
	[ -d "$entry" ] || return 1
	# A real directory is only ours when it contains links into the managed
	# roots; a locally installed skill holds real files instead.
	while IFS= read -r inner; do
		target="$(readlink "$inner")"
		case "$target" in
		*/Configs/agents/.agents/skills/* | */Configs/agents/.pi/agent/skills/*)
			return 0
			;;
		esac
	done < <(find "$entry" -type l)
	return 1
}

# ---------------------------------------------------------------------------
# Stale-link cleanup
# ---------------------------------------------------------------------------
# The link loops below never replace an existing entry, so a locally installed
# skill of the same name wins. The cost is that removing a managed skill leaves
# its harness link behind as a dangling symlink. This removes only that residue:
# a link is deleted only when it points into the managed skills root and its
# target is gone.

prune_stale_links() {
	local link_dir="$1" managed_root="$2" entry target
	[ -d "$link_dir" ] || return 0
	for entry in "$link_dir"/*; do
		[ -L "$entry" ] || continue
		target="$(readlink "$entry")"
		case "$target" in
		"$managed_root"/*) ;;
		*) continue ;;
		esac
		if [ ! -e "$entry" ]; then
			rm -f "$entry"
			echo "Pruned stale $(basename "$entry") link from $link_dir"
		fi
	done
}

# Drop disabled skills from the deployed tree before the link loops below run,
# so nothing re-links them and the Claude mirror never sees them.
remove_disabled_skill_links "$DEPLOYED_SKILLS_DIR"

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
		# This loop reads the repo, where disabled skills still have their files.
		if skill_is_disabled "$skill_name"; then
			continue
		fi
		target="$CODEX_SKILLS_DIR/$skill_name"
		if [ -e "$target" ] || [ -L "$target" ]; then
			continue
		fi
		ln -s "${skill_dir%/}" "$target"
		echo "Linked $skill_name into Codex skills"
	done
	prune_stale_links "$CODEX_SKILLS_DIR" "$MANAGED_SKILLS_DIR"
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
		# Disabled skills are cleared from the deployed tree above, but Tuckr
		# re-links them during its own deploy, so check again here.
		if skill_is_disabled "$skill_name"; then
			continue
		fi
		target="$CLAUDE_SKILLS_DIR/$skill_name"
		if [ -e "$target" ] || [ -L "$target" ]; then
			continue
		fi
		ln -s "${skill_dir%/}" "$target"
		echo "Linked $skill_name into Claude skills"
	done
	prune_stale_links "$CLAUDE_SKILLS_DIR" "$DEPLOYED_SKILLS_DIR"
fi

# ---------------------------------------------------------------------------
# Final check: disabled skills must not survive this deploy
# ---------------------------------------------------------------------------
# The loops above skip disabled skills, but Tuckr deploys the ~/.agents/skills
# tree itself and knows nothing about the toggle, so its per-file links are
# re-created on every run. Re-strip after everything else has finished, which
# makes this hook the last writer and keeps `dot skills` results stable
# regardless of when Tuckr last ran.
remove_disabled_skill_links "$DEPLOYED_SKILLS_DIR"
remove_disabled_skill_links "$CODEX_SKILLS_DIR"
remove_disabled_skill_links "$CLAUDE_SKILLS_DIR"
remove_disabled_skill_links "$PI_SKILLS_DIR"

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
