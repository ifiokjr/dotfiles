# shellcheck shell=sh
# ---------------------------------------------------------------------------
# Monosecret + 1Password secret injection
# ---------------------------------------------------------------------------
# Secrets are declared in ~/monosecret.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ss <args>        Run the Monosecret CLI with ~/monosecret.toml
#   ssr <command>    Run a command with secrets injected ephemerally
#   ssload           Load all declared secrets into the current shell session
# ---------------------------------------------------------------------------

ssr() {
	monosecret -f "$HOME/monosecret.toml" --reason "dotfiles secret injection" run -- "$@"
}

ss() {
	monosecret -f "$HOME/monosecret.toml" --reason "dotfiles secret management" "$@"
}

ssload() {
	_ss_file="$HOME/monosecret.toml"
	if [ ! -f "$_ss_file" ]; then
		echo "ssload: missing $_ss_file" >&2
		return 1
	fi

	# `monosecret env` emits shell-quoted exports for declared secret keys only.
	eval "$(monosecret -f "$_ss_file" --reason "dotfiles shell secret load" env --shell bash)"
	unset _ss_file
}
