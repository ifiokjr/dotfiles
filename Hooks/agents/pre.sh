#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(pwd)/../.." && pwd)"

# Codex previously exported a private copy of Computer Use into the shared skill
# directory. Move that copy aside once so Tuckr can install the managed bridge.
migrate_computer_use() {
	local managed_skill_dir="$DOTFILES_ROOT/Configs/agents/.agents/skills/computer-use"
	local deployed_skill_dir="$HOME/.agents/skills/computer-use"
	local backup_skill_dir="$HOME/.agents/computer-use-codex-export"

	if [ ! -d "$managed_skill_dir" ] || [ ! -d "$deployed_skill_dir" ]; then
		return 0
	fi

	if [ -L "$deployed_skill_dir" ] || [ -L "$deployed_skill_dir/SKILL.md" ]; then
		return 0
	fi

	if [ ! -d "$deployed_skill_dir/Codex Computer Use.app" ] || [ ! -f "$deployed_skill_dir/mcp.json" ]; then
		echo "Refusing to replace an unrecognized computer-use skill at $deployed_skill_dir" >&2
		return 1
	fi

	if [ -e "$backup_skill_dir" ]; then
		echo "Cannot migrate the Codex computer-use export because $backup_skill_dir already exists" >&2
		return 1
	fi

	mv "$deployed_skill_dir" "$backup_skill_dir"
	echo "Moved the previous Codex computer-use export to $backup_skill_dir"
}

# ---------------------------------------------------------------------------
# Migrate the skills-CLI copy of monochange to the dotfiles-managed skill
# ---------------------------------------------------------------------------
# `skills add -g` installed monochange as a real directory with copied files.
# Tuckr deploys managed skills as per-file symlinks and cannot overlay that
# copy, so move it aside once when it is not already managed.
migrate_monochange() {
	local managed_monochange_dir="$DOTFILES_ROOT/Configs/agents/.agents/skills/monochange"
	local deployed_monochange_dir="$HOME/.agents/skills/monochange"
	local backup_monochange_dir="$HOME/.agents/monochange-skills-cli-export"

	if [ ! -d "$managed_monochange_dir" ] || [ ! -d "$deployed_monochange_dir" ]; then
		return 0
	fi

	if [ -L "$deployed_monochange_dir" ] || [ -L "$deployed_monochange_dir/SKILL.md" ]; then
		return 0
	fi

	if [ -e "$backup_monochange_dir" ]; then
		echo "Cannot migrate the monochange skills-CLI copy because $backup_monochange_dir already exists" >&2
		return 1
	fi

	mv "$deployed_monochange_dir" "$backup_monochange_dir"
	echo "Moved the previous monochange skills-CLI copy to $backup_monochange_dir"
}

# ---------------------------------------------------------------------------
# Remove the superseded OpenCode config symlink
# ---------------------------------------------------------------------------
# The OpenCode config moved from config.json to opencode.json, because OpenCode
# silently ignores config.json and ran with default permissions the whole time.
# Tuckr only manages the files present in the group, so after the rename the old
# symlink stays behind as a dangling link into the repo. OpenCode ignores it the
# same way it ignored the real file, so this is tidiness rather than a fix, but a
# broken symlink in a config directory is a trap for whatever reads it next.
# Only a symlink into this repo is removed; a real config.json is left alone.
remove_stale_opencode_config() {
	local deployed_config="$HOME/.config/opencode/config.json"
	local tuckr_root
	tuckr_root="$(cd "$DOTFILES_ROOT/.." && pwd)"

	if [ ! -L "$deployed_config" ]; then
		return 0
	fi

	case "$(readlink "$deployed_config")" in
	"$tuckr_root"/* | "$DOTFILES_ROOT"/*)
		rm -f "$deployed_config"
		echo "Removed the superseded OpenCode config.json symlink"
		;;
	esac
}

migrate_computer_use
migrate_monochange
remove_stale_opencode_config
