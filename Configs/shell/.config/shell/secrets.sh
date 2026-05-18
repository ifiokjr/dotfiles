# ---------------------------------------------------------------------------
# SecretSpec + 1Password secret injection
# ---------------------------------------------------------------------------
# Replaces ~/.env.dotfiles. Secrets are declared in ~/secretspec.toml and
# resolved at runtime from a 1Password vault. Never written to disk.
#
# Usage:
#   ssr <command>   Run a command with secrets injected ephemerally
#   ssload          Load all secrets into the current shell session
#
# The LLM reads ~/secretspec.toml to discover what secrets are available
# (names + descriptions) without seeing values.
# ---------------------------------------------------------------------------

ssr() {
	secretspec run -f "$HOME/secretspec.toml" -- "$@"
}

ssload() {
	eval "$(secretspec run -f "$HOME/secretspec.toml" -- env | sed 's/^/export /')"
}
