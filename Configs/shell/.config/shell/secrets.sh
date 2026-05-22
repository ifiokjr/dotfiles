# shellcheck shell=sh
# ---------------------------------------------------------------------------
# SecretSpec + 1Password secret injection
# ---------------------------------------------------------------------------
# Secrets are declared in ~/secretspec.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ss <args>        Run the SecretSpec CLI with ~/secretspec.toml
#   ssr <command>    Run a command with secrets injected ephemerally
#   ssload           Load all declared secrets into the current shell session
# ---------------------------------------------------------------------------

ssr() {
	secretspec run -f "$HOME/secretspec.toml" -- "$@"
}

ss() {
	secretspec -f "$HOME/secretspec.toml" "$@"
}

ssload() {
	_ss_file="$HOME/secretspec.toml"
	if [ ! -f "$_ss_file" ]; then
		echo "ssload: missing $_ss_file" >&2
		return 1
	fi
	if ! command -v python3 >/dev/null 2>&1; then
		echo "ssload: python3 is required to quote secret values safely" >&2
		return 1
	fi

	_ss_keys=$(sed -n 's/^\[profiles\.default\.\([A-Za-z_][A-Za-z0-9_]*\)\]$/\1/p' "$_ss_file")
	if [ -z "$_ss_keys" ]; then
		echo "ssload: no secrets found in $_ss_file" >&2
		unset _ss_file _ss_keys
		return 1
	fi

	# `secretspec run` resolves every declared secret once. Python runs inside
	# that environment and emits shell-quoted exports for declared secret keys only.
	eval "$(
		SECRETSPEC_DOTFILES_KEYS="$_ss_keys" secretspec run -f "$_ss_file" -- python3 - <<'PY'
import os
import shlex

for key in os.environ.get("SECRETSPEC_DOTFILES_KEYS", "").splitlines():
    value = os.environ.get(key)
    if value is not None:
        print(f"export {key}={shlex.quote(value)}")
PY
	)"
	unset _ss_file _ss_keys
}
