#!/usr/bin/env bash
set -euo pipefail

SETUP_SCRIPT="$HOME/.config/codex/setup-codex.sh"

if [ ! -f "$SETUP_SCRIPT" ]; then
	echo "Codex setup script not found: $SETUP_SCRIPT" >&2
	exit 1
fi

bash "$SETUP_SCRIPT"
