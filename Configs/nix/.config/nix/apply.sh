#!/usr/bin/env bash
# Helper script to apply nix-darwin and home-manager configurations
# This is now a wrapper around the rebuild script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
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
	echo "This script is a wrapper around the 'rebuild' command."
	echo "For more options, use: rebuild --help"
	exit 0
fi

print_warn "This script is deprecated. Please use 'rebuild' instead."
print_info "Running rebuild..."
echo ""

# Increase file descriptor limit for Nix builds
ulimit -n 10240

# Use the rebuild script with explicit #default
if sudo darwin-rebuild switch --flake "$SCRIPT_DIR#default"; then
	print_info "Configuration applied successfully!"
	print_info "Both system (darwin) and user (home-manager) configurations have been updated."
	print_info "You may need to restart your shell for some changes to take effect."
else
	print_error "Failed to apply configuration"
	exit 1
fi
