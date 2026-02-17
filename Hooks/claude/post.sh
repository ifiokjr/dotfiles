#!/usr/bin/env bash

# post_claude - Register MCP servers and cache Deno dependencies

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}✓${NC} Claude configuration deployed"

# ---------------------------------------------------------------------------
# PATH augmentation — ensure nix-installed tools (claude, deno, etc.)
# are discoverable even when this hook runs before the user's shell profile.
# ---------------------------------------------------------------------------
for p in "/etc/profiles/per-user/${USER}/bin" "/run/current-system/sw/bin" \
	"$HOME/.nix-profile/bin" "/nix/var/nix/profiles/default/bin"; do
	# shellcheck disable=SC2249
	[ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$p:$PATH" ;; esac
done

# Resolve the real path of the MCP server (follows symlinks portably)
MCP_SERVER="$HOME/.claude/skills/tart_vm_control/mcp-server-tart.ts"
if [ -f "$MCP_SERVER" ]; then
	# Portable symlink resolution (no readlink -f on macOS)
	REAL_DIR=$(cd "$(dirname "$MCP_SERVER")" && pwd -P)
	REAL_PATH="$REAL_DIR/$(basename "$MCP_SERVER")"
else
	echo -e "${YELLOW}!${NC} MCP server not found at $MCP_SERVER, skipping registration"
	exit 0
fi

# Register MCP server with Claude Code
if command -v claude &>/dev/null; then
	# Unset CLAUDECODE to prevent nested session detection
	unset CLAUDECODE
	claude mcp add --scope user tart-vm -- deno run -A "$REAL_PATH"
	echo -e "${GREEN}✓${NC} Registered tart-vm MCP server"
else
	echo -e "${YELLOW}!${NC} claude not found, skipping MCP server registration"
fi

# Cache Deno dependencies
if command -v deno &>/dev/null; then
	echo -e "${BLUE}→${NC} Caching Deno dependencies..."
	deno cache "$REAL_PATH" 2>/dev/null &&
		echo -e "${GREEN}✓${NC} Deno dependencies cached" ||
		echo -e "${YELLOW}!${NC} Deno cache failed (will retry on first run)"
else
	echo -e "${YELLOW}!${NC} deno not found, skipping dependency caching"
fi
