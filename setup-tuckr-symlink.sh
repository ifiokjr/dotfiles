#!/usr/bin/env bash
#
# Tuckr Platform Symlink Setup
#
# This script creates a platform-specific symlink from the expected tuckr location
# to the actual dotfiles repository in ~/Developer/.dotfiles
#
# Tuckr expects dotfiles in different locations per platform:
#   - macOS:       ~/Library/Application Support/dotfiles
#   - Linux/BSD:   ~/.config/dotfiles (primary) or ~/.dotfiles (fallback)
#   - Windows:     %HomePath%\AppData\Roaming\dotfiles or %HomePath%\.dotfiles
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Dotfiles repository location (canonical source)
DOTFILES_REPO="$HOME/Developer/.dotfiles"

# Detect platform and set target symlink location
detect_platform() {
    case "$(uname -s)" in
        Darwin*)
            PLATFORM="macos"
            TUCKR_LOCATION="$HOME/Library/Application Support/dotfiles"
            ;;
        Linux*)
            PLATFORM="linux"
            TUCKR_LOCATION="$HOME/.config/dotfiles"
            ;;
        CYGWIN*|MINGW32*|MINGW64*|MINGW*|MSYS*)
            PLATFORM="windows"
            TUCKR_LOCATION="$HOME/AppData/Roaming/dotfiles"
            ;;
        FreeBSD*|OpenBSD*|NetBSD*)
            PLATFORM="bsd"
            TUCKR_LOCATION="$HOME/.config/dotfiles"
            ;;
        *)
            echo -e "${RED}Error: Unknown platform $(uname -s)${NC}"
            exit 1
            ;;
    esac
}

# Check if dotfiles repository exists
check_repo_exists() {
    if [ ! -d "$DOTFILES_REPO" ]; then
        echo -e "${RED}Error: Dotfiles repository not found at $DOTFILES_REPO${NC}"
        echo "Please ensure your dotfiles are located at $DOTFILES_REPO"
        exit 1
    fi
}

# Create symlink
create_symlink() {
    local target_dir
    target_dir="$(dirname "$TUCKR_LOCATION")"

    echo -e "${BLUE}Platform detected: $PLATFORM${NC}"
    echo -e "${BLUE}Dotfiles location: $DOTFILES_REPO${NC}"
    echo -e "${BLUE}Tuckr expects:     $TUCKR_LOCATION${NC}"
    echo ""

    # Create parent directory if it doesn't exist
    if [ ! -d "$target_dir" ]; then
        echo -e "${YELLOW}Creating parent directory: $target_dir${NC}"
        mkdir -p "$target_dir"
    fi

    # Check if target already exists
    if [ -e "$TUCKR_LOCATION" ] || [ -L "$TUCKR_LOCATION" ]; then
        # Check if it's already the correct symlink
        if [ -L "$TUCKR_LOCATION" ]; then
            local current_target
            current_target="$(readlink "$TUCKR_LOCATION")"
            if [ "$current_target" = "$DOTFILES_REPO" ]; then
                echo -e "${GREEN}✓ Symlink already exists and points to correct location${NC}"
                echo -e "  $TUCKR_LOCATION → $DOTFILES_REPO"
                return 0
            else
                echo -e "${YELLOW}Warning: Symlink exists but points to different location${NC}"
                echo -e "  Current: $TUCKR_LOCATION → $current_target"
                echo -e "  Expected: $TUCKR_LOCATION → $DOTFILES_REPO"
                read -p "Remove existing symlink and create new one? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${RED}Aborted${NC}"
                    exit 1
                fi
                rm "$TUCKR_LOCATION"
            fi
        else
            echo -e "${RED}Error: Path already exists and is not a symlink: $TUCKR_LOCATION${NC}"
            echo "Please move or remove this directory before running this script."
            exit 1
        fi
    fi

    # Create the symlink
    echo -e "${YELLOW}Creating symlink...${NC}"
    ln -s "$DOTFILES_REPO" "$TUCKR_LOCATION"

    # Verify
    if [ -L "$TUCKR_LOCATION" ] && [ "$(readlink "$TUCKR_LOCATION")" = "$DOTFILES_REPO" ]; then
        echo -e "${GREEN}✓ Success! Symlink created${NC}"
        echo -e "  $TUCKR_LOCATION → $DOTFILES_REPO"
        echo ""
        echo -e "${GREEN}Tuckr is now configured to use your dotfiles.${NC}"
        echo "You can run 'tuckr status' to verify."
    else
        echo -e "${RED}Error: Failed to create symlink${NC}"
        exit 1
    fi
}

# Main
main() {
    echo -e "${BLUE}=== Tuckr Platform Symlink Setup ===${NC}"
    echo ""

    detect_platform
    check_repo_exists
    create_symlink

    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
}

main "$@"
