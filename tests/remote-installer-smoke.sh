#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-$PWD}"
PORT="${REMOTE_INSTALLER_SMOKE_PORT:-18080}"
SERVER_URL="http://127.0.0.1:${PORT}"
TMP_DIR="$(mktemp -d)"
HELP_OUTPUT="$TMP_DIR/help.txt"
SERVER_LOG="$TMP_DIR/http-server.log"
server_pid=""

cleanup() {
	if [ -n "$server_pid" ]; then
		kill "$server_pid" >/dev/null 2>&1 || true
		wait "$server_pid" >/dev/null 2>&1 || true
	fi
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

echo "Starting local HTTP server from: $REPO_DIR"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$REPO_DIR" >"$SERVER_LOG" 2>&1 &
server_pid="$!"

for _ in $(seq 1 30); do
	if curl -fsSL "$SERVER_URL/setup" >/dev/null 2>&1; then
		break
	fi
	sleep 1
done

curl -fsSL "$SERVER_URL/setup" >/dev/null

echo "Checking remote --help output"
curl -fsSL "$SERVER_URL/setup" | bash -s -- --help >"$HELP_OUTPUT"
grep -Fq "Dotfiles Setup Script" "$HELP_OUTPUT"
grep -Fq "Remote: curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash" "$HELP_OUTPUT"
grep -Fq -- "--preset NAME" "$HELP_OUTPUT"

echo "Running remote installer against the checked-out branch"
curl -fsSL "$SERVER_URL/setup" | bash -s -- --cwd "$REPO_DIR" --skip-nix --no-confirm --preset core

echo "Verifying core preset state"
command -v tuckr >/dev/null
command -v nu >/dev/null
test -L "$HOME/.config/nushell/config.nu"
test -L "$HOME/.config/helix/config.toml"
test -L "$HOME/.zshrc"

echo "Remote installer smoke test passed"
