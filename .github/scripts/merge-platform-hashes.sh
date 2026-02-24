#!/usr/bin/env bash
# Merge Nix package hashes from macOS and Linux CI artifacts.
#
# macOS artifacts contain correct darwin hashes (prefetched on macOS).
# Linux artifacts contain correct linux hashes (prefetched on Linux).
# This script takes the macOS file as base and overlays Linux hashes.
#
# Usage: merge-platform-hashes.sh <macos_artifacts_dir> <linux_artifacts_dir> <target_nix_dir>

set -euo pipefail

MACOS_DIR="${1:?Usage: merge-platform-hashes.sh <macos_dir> <linux_dir> <target_dir>}"
LINUX_DIR="${2:?}"
TARGET_DIR="${3:?}"

# Copy flake.lock (platform-independent) from macOS artifact
cp "$MACOS_DIR/flake.lock" "$TARGET_DIR/flake.lock"

# Linux hash keys used across custom packages
SIMPLE_KEYS=("linux-x64" "linux-arm64")
NESTED_KEYS=(
	"x86_64-linux"
	"aarch64-linux"
	"x86_64-unknown-linux-musl"
	"aarch64-unknown-linux-musl"
	"x86_64-linux-buster"
	"aarch64-linux-buster"
)

# Process each macOS package file
for pkg_file in "$MACOS_DIR"/packages/*.nix; do
	filename=$(basename "$pkg_file")
	target="$TARGET_DIR/packages/$filename"
	linux_file="$LINUX_DIR/packages/$filename"

	if [ ! -f "$linux_file" ]; then
		# No Linux counterpart — use macOS version as-is
		cp "$pkg_file" "$target"
		continue
	fi

	# Start with macOS file (has correct darwin hashes)
	cp "$pkg_file" "$target"

	# Overlay simple key = "hash" patterns (e.g. pnpm, cursor)
	for key in "${SIMPLE_KEYS[@]}"; do
		linux_hash=$(grep -oP "\"${key}\" = \"[^\"]+\"" "$linux_file" 2>/dev/null || true)
		if [ -n "$linux_hash" ]; then
			sed -i "s|\"${key}\" = \"[^\"]*\"|${linux_hash}|g" "$target"
		fi
	done

	# Overlay nested hash patterns (e.g. google-chrome, codex)
	# Matches either: "key" = "sha256-..." or "key" = { ... hash = "sha256-..." ... }
	for key in "${NESTED_KEYS[@]}"; do
		# Try simple pattern: "key" = "hash"
		hash_value=$(grep -oP "\"${key}\" = \"\\K[^\"]+(?=\")" "$linux_file" 2>/dev/null || true)
		if [ -n "$hash_value" ]; then
			sed -i "s|\(\"${key}\" = \)\"[^\"]*\"|\1\"${hash_value}\"|g" "$target"
			continue
		fi

		# Try nested pattern: "key" = { ... hash = "hash" ... }
		# Extract the hash value from the block
		hash_value=$(sed -n "/\"${key}\"/,/}/{ s/.*hash = \"\([^\"]*\)\".*/\1/p; }" "$linux_file" 2>/dev/null || true)
		if [ -n "$hash_value" ]; then
			# Replace the hash inside the matching key block in target
			sed -i "/\"${key}\"/,/}/ s|hash = \"[^\"]*\"|hash = \"${hash_value}\"|" "$target"
		fi
	done
done

# Copy any package files that only exist in the Linux artifact
for pkg_file in "$LINUX_DIR"/packages/*.nix; do
	filename=$(basename "$pkg_file")
	macos_file="$MACOS_DIR/packages/$filename"
	if [ ! -f "$macos_file" ]; then
		cp "$pkg_file" "$TARGET_DIR/packages/$filename"
	fi
done

echo "Platform hashes merged successfully"
