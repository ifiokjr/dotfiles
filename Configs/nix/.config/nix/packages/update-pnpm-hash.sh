#!/usr/bin/env bash
#
# Automatically update pnpm-standalone hash
#
# This script:
# 1. Detects your platform (macos-arm64, macos-x64, etc.)
# 2. Runs darwin-rebuild to get the correct hash
# 3. Extracts the hash from the error message
# 4. Updates pnpm-standalone.nix with the correct hash
# 5. Runs darwin-rebuild again to complete the installation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
	echo -e "${BLUE}==>${NC} $1"
}

print_success() {
	echo -e "${GREEN}✓${NC} $1"
}

print_error() {
	echo -e "${RED}✗${NC} $1"
}

print_warn() {
	echo -e "${YELLOW}!${NC} $1"
}

# Detect platform
detect_platform() {
	local os arch

	case "$(uname -s)" in
	Darwin) os="macos" ;;
	Linux) os="linux" ;;
	*)
		print_error "Unsupported OS: $(uname -s)"
		exit 1
		;;
	esac

	case "$(uname -m)" in
	arm64 | aarch64) arch="arm64" ;;
	x86_64) arch="x64" ;;
	*)
		print_error "Unsupported architecture: $(uname -m)"
		exit 1
		;;
	esac

	echo "${os}-${arch}"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="${SCRIPT_DIR}/pnpm-standalone.nix"

if [[ ! -f "$NIX_FILE" ]]; then
	print_error "Could not find pnpm-standalone.nix at: $NIX_FILE"
	exit 1
fi

PLATFORM=$(detect_platform)
print_info "Detected platform: $PLATFORM"

# Get version from nix file
VERSION=$(grep 'version = ' "$NIX_FILE" | sed -E 's/.*version = "([^"]+)".*/\1/')
if [[ -z "$VERSION" ]]; then
	print_error "Could not extract version from $NIX_FILE"
	exit 1
fi

print_info "Fetching pnpm version $VERSION for $PLATFORM"

# Construct download URL
PNPM_URL="https://github.com/pnpm/pnpm/releases/download/v${VERSION}/pnpm-${PLATFORM}"

print_info "Fetching hash using nix-prefetch-url..."
echo ""

# Use nix-prefetch-url to get the correct hash
# This is the proper Nix way and doesn't require sudo
CORRECT_HASH=$(nix-prefetch-url --type sha256 "$PNPM_URL" 2>&1 | tail -1)

if [[ -z "$CORRECT_HASH" ]]; then
	print_error "Failed to fetch hash from $PNPM_URL"
	exit 1
fi

# Convert to SRI format (sha256-...) if it's in the old format
if [[ ! "$CORRECT_HASH" =~ ^sha256- ]]; then
	print_info "Converting hash to SRI format..."
	CORRECT_HASH=$(nix hash to-sri --type sha256 "$CORRECT_HASH")
fi

print_success "Found hash: $CORRECT_HASH"
echo ""

# Backup the file
cp "$NIX_FILE" "${NIX_FILE}.backup"
print_info "Created backup: ${NIX_FILE}.backup"

# Update the hash in the file
# Replace the line with the platform hash
if grep -q "\"${PLATFORM}\"" "$NIX_FILE"; then
	# Use sed to replace the hash
	if [[ "$OSTYPE" == "darwin"* ]]; then
		# macOS sed syntax
		sed -i '' "s|\"${PLATFORM}\" = .*|\"${PLATFORM}\" = \"${CORRECT_HASH}\";|" "$NIX_FILE"
	else
		# Linux sed syntax
		sed -i "s|\"${PLATFORM}\" = .*|\"${PLATFORM}\" = \"${CORRECT_HASH}\";|" "$NIX_FILE"
	fi
	print_success "Updated hash in pnpm-standalone.nix"
else
	print_error "Could not find platform entry for: $PLATFORM"
	exit 1
fi

echo ""
print_success "Hash updated successfully!"

# Clean up backup
rm "${NIX_FILE}.backup"
print_info "Removed backup file"

echo ""
print_info "Run 'rebuild' to apply the changes."
