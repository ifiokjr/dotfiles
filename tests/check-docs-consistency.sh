#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
README_FILE="$ROOT_DIR/readme.md"
SETUP_DOC="$ROOT_DIR/docs/agents/setup-and-deployment.md"
GETTING_STARTED_DOC="$ROOT_DIR/docs/getting-started.md"

fail() {
	echo "docs consistency check failed: $1" >&2
	exit 1
}

require_contains() {
	local needle="$1"
	local file="$2"
	grep -Fq -- "$needle" "$file" || fail "$file is missing: $needle"
}

require_file() {
	local file="$1"
	[ -f "$file" ] || fail "missing file: $file"
}

main() {
	local options=()
	local option

	require_file "$README_FILE"
	require_file "$SETUP_DOC"
	require_file "$GETTING_STARTED_DOC"

	while IFS= read -r option; do
		[ -n "$option" ] || continue
		options+=("$option")
	done < <("$ROOT_DIR/setup" --help | sed -n 's/^  \(--[^ ]*\).*/\1/p')

	if [ ${#options[@]} -eq 0 ]; then
		fail "could not parse setup options from --help"
	fi

	for option in "${options[@]}"; do
		require_contains "$option" "$README_FILE"
		require_contains "$option" "$SETUP_DOC"
	done

	require_contains "docs/getting-started.md" "$README_FILE"
	require_contains "Starter Workflows" "$GETTING_STARTED_DOC"

	echo "docs consistency check passed"
}

main "$@"
