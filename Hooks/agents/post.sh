#!/usr/bin/env bash
set -euo pipefail

# post.sh - Agents configuration post-install hook
# Installs OpenCode plugins and tools

echo "Setting up AI agents configuration..."

# ---------------------------------------------------------------------------
# Install OCX (OpenCode eXtensions manager) if not present
# ---------------------------------------------------------------------------
if ! command -v ocx &>/dev/null; then
	echo "Installing OCX (OpenCode eXtensions manager)..."
	# OCX is distributed via npm - prefer pnpm for global installs
	if command -v pnpm &>/dev/null; then
		pnpm add -g @kdcokenny/ocx || echo "Warning: Failed to install OCX via pnpm"
	elif command -v npm &>/dev/null; then
		npm install -g @kdcokenny/ocx || echo "Warning: Failed to install OCX via npm"
	else
		echo "Warning: No Node.js package manager found, skipping OCX installation"
	fi
else
	echo "OCX already installed: $(which ocx)"
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
	echo "To install manually later, run:"
	echo "  pnpm add -g @kdcokenny/ocx"
	echo "  ocx add kdco/worktree --from https://registry.kdco.dev"
fi

echo "Agents configuration complete!"
