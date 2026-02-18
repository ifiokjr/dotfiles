#!/usr/bin/env bash
#
# Automatically update pnpm-standalone hashes for ALL platforms
#
# This script:
# 1. Reads the current version from pnpm-standalone.nix
# 2. Fetches hashes for all 4 platforms using nix-prefetch-url
# 3. Updates pnpm-standalone.nix with the correct hashes

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="${SCRIPT_DIR}/pnpm-standalone.nix"

if [[ ! -f "$NIX_FILE" ]]; then
	print_error "Could not find pnpm-standalone.nix at: $NIX_FILE"
	exit 1
fi

# Get version from nix file
VERSION=$(grep 'version = ' "$NIX_FILE" | sed -E 's/.*version = "([^"]+)".*/\1/')
if [[ -z "$VERSION" ]]; then
	print_error "Could not extract version from $NIX_FILE"
	exit 1
fi

print_info "Fetching pnpm v$VERSION hashes for all platforms..."
echo ""

# All supported platforms
PLATFORMS=("macos-arm64" "macos-x64" "linux-arm64" "linux-x64")

# Backup the file
cp "$NIX_FILE" "${NIX_FILE}.backup"

fetch_hash() {
	local platform="$1"
	local url="https://github.com/pnpm/pnpm/releases/download/v${VERSION}/pnpm-${platform}"

	print_info "Fetching hash for $platform..." >&2

	local raw_hash
	raw_hash=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null | tail -1)

	if [[ -z "$raw_hash" ]]; then
		print_error "Failed to fetch hash for $platform" >&2
		return 1
	fi

	# Convert to SRI format
	local sri_hash
	sri_hash=$(nix hash to-sri --type sha256 "$raw_hash" 2>/dev/null || nix hash convert --hash-algo sha256 --to sri "$raw_hash")

	echo "$sri_hash"
}

ALL_OK=true

for platform in "${PLATFORMS[@]}"; do
	HASH=$(fetch_hash "$platform")
	if [[ -z "$HASH" ]]; then
		print_error "Failed to get hash for $platform"
		ALL_OK=false
		continue
	fi

	print_success "$platform: $HASH"

	# Update the hash in the file (handle both quoted hashes and lib.fakeSha256)
	if [[ "$OSTYPE" == "darwin"* ]]; then
		sed -i '' "s|\"${platform}\" = .*|\"${platform}\" = \"${HASH}\";|" "$NIX_FILE"
	else
		sed -i "s|\"${platform}\" = .*|\"${platform}\" = \"${HASH}\";|" "$NIX_FILE"
	fi
done

echo ""

if [[ "$ALL_OK" = true ]]; then
	rm -f "${NIX_FILE}.backup"
	print_success "All hashes updated successfully!"
else
	print_error "Some hashes failed. Restoring backup."
	mv "${NIX_FILE}.backup" "$NIX_FILE"
	exit 1
fi

echo ""
print_info "Run 'rebuild' to apply the changes."
