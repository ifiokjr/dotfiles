#!/usr/bin/env bash
set -euo pipefail

# Codex previously exported a private copy of Computer Use into the shared skill
# directory. Move that copy aside once so Tuckr can install the managed bridge.
DOTFILES_ROOT="$(cd "$(pwd)/../.." && pwd)"
MANAGED_SKILL_DIR="$DOTFILES_ROOT/Configs/agents/.agents/skills/computer-use"
DEPLOYED_SKILL_DIR="$HOME/.agents/skills/computer-use"
BACKUP_SKILL_DIR="$HOME/.agents/computer-use-codex-export"

if [ ! -d "$MANAGED_SKILL_DIR" ] || [ ! -d "$DEPLOYED_SKILL_DIR" ]; then
	exit 0
fi

if [ -L "$DEPLOYED_SKILL_DIR" ] || [ -L "$DEPLOYED_SKILL_DIR/SKILL.md" ]; then
	exit 0
fi

if [ ! -d "$DEPLOYED_SKILL_DIR/Codex Computer Use.app" ] || [ ! -f "$DEPLOYED_SKILL_DIR/mcp.json" ]; then
	echo "Refusing to replace an unrecognized computer-use skill at $DEPLOYED_SKILL_DIR" >&2
	exit 1
fi

if [ -e "$BACKUP_SKILL_DIR" ]; then
	echo "Cannot migrate the Codex computer-use export because $BACKUP_SKILL_DIR already exists" >&2
	exit 1
fi

mv "$DEPLOYED_SKILL_DIR" "$BACKUP_SKILL_DIR"
echo "Moved the previous Codex computer-use export to $BACKUP_SKILL_DIR"
