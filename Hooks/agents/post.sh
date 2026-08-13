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

echo "Agents configuration complete!"
