#!/usr/bin/env bash
# Helper script to apply nix-darwin and home-manager configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}==>${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}==>${NC} $1"
}

print_error() {
    echo -e "${RED}==>${NC} $1"
}

# Parse arguments
PURE_MODE=false
CONFIG_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --pure)
            PURE_MODE=true
            shift
            ;;
        --config)
            CONFIG_NAME="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --pure          Use pure evaluation (requires named config)"
            echo "  --config NAME   Use specific configuration name"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                         # Auto-detect user"
            echo "  $0 --config alice          # Use specific named config"
            echo ""
            echo "Note: home-manager is integrated into darwin, so this script"
            echo "      only needs to run darwin-rebuild to apply both configurations."
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Build flake reference
if [[ -n "$CONFIG_NAME" ]]; then
    FLAKE_REF=".#$CONFIG_NAME"
else
    FLAKE_REF=".#"
fi

# Add --impure flag if not in pure mode
IMPURE_FLAG=""
if [[ "$PURE_MODE" = false ]]; then
    IMPURE_FLAG="--impure"
    print_info "Using impure mode to auto-detect username: $USER"
else
    print_info "Using pure mode with configuration: ${CONFIG_NAME:-default}"
fi

# Check if flake is valid
print_info "Checking flake configuration..."
if ! nix flake check $IMPURE_FLAG; then
    print_error "Flake check failed. Please fix errors before continuing."
    exit 1
fi

# Apply darwin configuration (includes home-manager)
print_info "Applying nix-darwin configuration (includes home-manager)..."
if darwin-rebuild switch --flake "$FLAKE_REF" $IMPURE_FLAG; then
    print_info "Configuration applied successfully!"
    print_info "Both system (darwin) and user (home-manager) configurations have been updated."
    print_info "You may need to restart your shell for some changes to take effect."
else
    print_error "Failed to apply configuration"
    exit 1
fi
