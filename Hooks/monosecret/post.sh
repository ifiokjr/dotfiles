#!/usr/bin/env bash

# post_monosecret - Prepare optional local fallback files for Monosecret.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

ENV_FILE="$HOME/.env.dotfiles"
EXAMPLE_FILE="Configs/monosecret/.env.dotfiles.example"

echo -e "${GREEN}✓${NC} Monosecret configuration deployed"

if [ ! -f "$ENV_FILE" ]; then
	if [ -f "$EXAMPLE_FILE" ]; then
		cp "$EXAMPLE_FILE" "$ENV_FILE"
		chmod 600 "$ENV_FILE"
		echo -e "${GREEN}✓${NC} Created optional $ENV_FILE fallback"
		echo -e "${BLUE}→${NC} Primary secrets come from Monosecret + 1Password; this file is only for OP_SERVICE_ACCOUNT_TOKEN fallback"
	else
		echo -e "${YELLOW}!${NC} Warning: Could not find $EXAMPLE_FILE"
	fi
else
	chmod 600 "$ENV_FILE" 2>/dev/null || true
	echo -e "${BLUE}→${NC} $ENV_FILE already exists (not overwriting)"
fi
