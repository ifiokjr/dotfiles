#!/usr/bin/env bash
# Helper script to apply nix-darwin and home-manager configurations
# This is now a wrapper around `dot rebuild`

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
	echo -e "${BLUE}==>${NC} $1"
}

print_warn() {
	echo -e "${YELLOW}==>${NC} $1"
}

print_error() {
	echo -e "${RED}==>${NC} $1"
}

# Check for help flag
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	echo "Usage: $0"
	echo ""
	echo "Apply nix-darwin and home-manager configurations"
	echo "Configuration is read from machine.nix (see machine.nix.example)"
	echo ""
	echo "This script is a wrapper around the 'dot rebuild' command."
	echo "For more options, use: dot rebuild --help"
	exit 0
fi

print_warn "This script is deprecated. Please use 'dot rebuild' instead."
print_info "Running rebuild..."
echo ""

# `dot rebuild` passes --impure and NIX_USER_CONFIG_DIR, which the flake needs to
# read the gitignored machine.nix; a bare `darwin-rebuild switch` cannot see it.
exec "$HOME/.local/bin/dot" rebuild "$@"
