# ---------------------------------------------------------------------------
# SecretSpec + 1Password secret injection
# ---------------------------------------------------------------------------
# Secrets are declared in ~/secretspec.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ss <command>    Run a command with secrets injected ephemerally
# ---------------------------------------------------------------------------

ss() {
	secretspec run -f "$HOME/secretspec.toml" -- "$@"
}
