#!/usr/bin/env bash

# Generate dotfiles CLI bash completions when the bash group is deployed.
# The generated file is also sourced explicitly from .bashrc, so this works on
# systems that do not have bash-completion's completion directory autoloading.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
DOT_COMPLETION_FILE="$COMPLETION_DIR/dot"
DOTFILES_COMPLETION_FILE="$COMPLETION_DIR/dotfiles"

if ! command -v dot >/dev/null 2>&1; then
	echo -e "${YELLOW}!${NC} dot not found, skipping dotfiles bash completions"
	exit 0
fi

mkdir -p "$COMPLETION_DIR"

if dot completion bash >"$DOT_COMPLETION_FILE"; then
	ln -sf "$DOT_COMPLETION_FILE" "$DOTFILES_COMPLETION_FILE"
	echo -e "${GREEN}✓${NC} Generated dotfiles bash completions"
else
	rm -f "$DOT_COMPLETION_FILE"
	echo -e "${YELLOW}!${NC} dot completion bash failed, skipping dotfiles bash completions"
fi
