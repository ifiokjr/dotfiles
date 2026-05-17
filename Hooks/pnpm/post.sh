#!/usr/bin/env bash
set -euo pipefail

# Install the Tuckr-managed pnpm global project dependencies.
SYNC_SCRIPT="$HOME/.local/bin/pnpm:global:sync"

# Fallback for partial/manual deployments where scripts group is not linked yet.
if [ ! -x "$SYNC_SCRIPT" ]; then
	THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
	FALLBACK_SCRIPT="$(cd "$THIS_DIR/../.." && pwd -P)/Configs/scripts/.local/bin/pnpm:global:sync"
	if [ -x "$FALLBACK_SCRIPT" ]; then
		SYNC_SCRIPT="$FALLBACK_SCRIPT"
	fi
fi

if [ -x "$SYNC_SCRIPT" ]; then
	# Setup may run before nix rebuild finishes in CI containers.
	# Treat pnpm sync as best-effort during hook execution.
	"$SYNC_SCRIPT" --no-fail
else
	echo "pnpm:global:sync not found at ~/.local/bin; skipping"
fi
