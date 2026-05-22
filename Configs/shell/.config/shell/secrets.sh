# shellcheck shell=sh
# ---------------------------------------------------------------------------
# SecretSpec + 1Password secret injection
# ---------------------------------------------------------------------------
# Secrets are declared in ~/secretspec.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ssr <command>    Run a command with secrets injected ephemerally
# ---------------------------------------------------------------------------

ssr() {
	secretspec run -f "$HOME/secretspec.toml" -- "$@"
}

ss() {
	secretspec -f "$HOME/secretspec.toml" "$@"
}
