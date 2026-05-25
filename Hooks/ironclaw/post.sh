#!/usr/bin/env bash
set -euo pipefail

# post.sh - Ironclaw configuration post-install hook
#
# Merges defaults from ~/.ironclaw/.env.base (managed by tuckr) into
# ~/.ironclaw/.env (which may contain secrets and is not tracked by git).
#
# Ironclaw uses ~/.ironclaw/ as a workspace directory (for session.json,
# ironclaw.db, etc.) and loads ~/.ironclaw/.env via dotenvy on startup.
#
# Strategy:
#   - If ~/.ironclaw/.env does not exist, create it from .env.base.
#   - If ~/.ironclaw/.env exists, update any keys present in .env.base
#     with the new default value, preserving keys that only exist in
#     ~/.ironclaw/.env (e.g. secret tokens).

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

IRONCLAW_DIR="$HOME/.ironclaw"
IRONCLAW_FILE="$IRONCLAW_DIR/.env"
BASE_FILE="$IRONCLAW_DIR/.env.base"

if [ ! -f "$BASE_FILE" ]; then
	echo -e "${YELLOW}!${NC} ~/.ironclaw/.env.base not found, skipping ironclaw config generation"
	exit 0
fi

# Ensure the workspace directory exists (ironclaw also creates this on first run)
mkdir -p "$IRONCLAW_DIR"

if [ ! -f "$IRONCLAW_FILE" ]; then
	# First deploy: copy base as the initial config
	cp "$BASE_FILE" "$IRONCLAW_FILE"
	chmod 600 "$IRONCLAW_FILE"
	echo -e "${GREEN}✓${NC} Created ~/.ironclaw/.env from base defaults"
	echo -e "${BLUE}→${NC} Add secret values (NEARAI_SESSION_TOKEN, NEARAI_API_KEY) to ~/.ironclaw/.env"
else
	# Merge: update keys defined in base, preserve everything else
	TEMP_FILE="$(mktemp)"

	# Start with the existing file (preserves secret-only keys and comments)
	cp "$IRONCLAW_FILE" "$TEMP_FILE"

	# For each KEY=VALUE line in the base file, update or append in the temp file
	while IFS= read -r line; do
		# Skip comments and blank lines
		case "$line" in
		'#'* | '') continue ;;
		esac

		key="${line%%=*}"

		# If the key exists in the temp file, replace its value
		if grep -q "^${key}=" "$TEMP_FILE" 2>/dev/null; then
			# Use sed to replace the value (escape special chars in replacement)
			escaped_value="${line#*=}"
			sed -i.bak "s|^${key}=.*|${key}=${escaped_value}|" "$TEMP_FILE"
			rm -f "$TEMP_FILE.bak"
		else
			# Append new key
			echo "$line" >>"$TEMP_FILE"
		fi
	done <"$BASE_FILE"

	# Preserve permissions
	chmod --reference="$IRONCLAW_FILE" "$TEMP_FILE" 2>/dev/null || chmod 600 "$TEMP_FILE"
	mv "$TEMP_FILE" "$IRONCLAW_FILE"
	echo -e "${GREEN}✓${NC} Merged base defaults into ~/.ironclaw/.env (secrets preserved)"
fi
