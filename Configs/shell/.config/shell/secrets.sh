# shellcheck shell=sh
# ---------------------------------------------------------------------------
# Monosecret + 1Password secret injection
# ---------------------------------------------------------------------------
# Secrets are declared in ~/monosecret.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ms <args>        Run the Monosecret CLI with ~/monosecret.toml
#   msr <command>    Run a command with secrets injected ephemerally
#   msload           Load all declared secrets into the current shell session
# ---------------------------------------------------------------------------

msr() {
	monosecret -f "$HOME/monosecret.toml" --reason "dotfiles secret injection" run -- "$@"
}

ms() {
	monosecret -f "$HOME/monosecret.toml" --reason "dotfiles secret management" "$@"
}

msload() {
	_ms_file="$HOME/monosecret.toml"
	if [ ! -f "$_ms_file" ]; then
		echo "msload: missing $_ms_file" >&2
		return 1
	fi

	# `monosecret env` emits shell-quoted exports for declared secret keys only.
	eval "$(monosecret -f "$_ms_file" --reason "dotfiles shell secret load" env --shell bash)"
	unset _ms_file
}
