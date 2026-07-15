# shellcheck shell=sh
# ---------------------------------------------------------------------------
# Monosecret + 1Password secret injection
# ---------------------------------------------------------------------------
# Secrets are declared in ~/monosecret.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ms <args>                           Run the Monosecret CLI with ~/monosecret.toml
#   msr --reason <text> <command>       Run a command with secrets injected ephemerally
#   msload --reason <text>              Load all declared secrets into the current shell session
# ---------------------------------------------------------------------------

msr() {
	if [ "$#" -lt 2 ] || [ "$1" != "--reason" ] || [ -z "$2" ]; then
		echo "usage: msr --reason <text> <command> [args...]" >&2
		return 2
	fi
	case "$2" in
	*[![:space:]]*) ;;
	*)
		echo "msr: --reason <text> must not be blank" >&2
		return 2
		;;
	esac

	_ms_reason="$2"
	shift 2
	if [ "$#" -eq 0 ]; then
		echo "msr: a command is required after --reason <text>" >&2
		unset _ms_reason
		return 2
	fi

	if monosecret -f "$HOME/monosecret.toml" --reason "$_ms_reason" run -- "$@"; then
		unset _ms_reason
		return 0
	fi
	unset _ms_reason
	return 1
}

ms() {
	monosecret -f "$HOME/monosecret.toml" --reason "dotfiles secret management" "$@"
}

msload() {
	if [ "$#" -ne 2 ] || [ "$1" != "--reason" ] || [ -z "$2" ]; then
		echo "usage: msload --reason <text>" >&2
		return 2
	fi
	case "$2" in
	*[![:space:]]*) ;;
	*)
		echo "msload: --reason <text> must not be blank" >&2
		return 2
		;;
	esac

	_ms_reason="$2"
	_ms_file="$HOME/monosecret.toml"
	if [ ! -f "$_ms_file" ]; then
		echo "msload: missing $_ms_file" >&2
		unset _ms_reason _ms_file
		return 1
	fi

	# `monosecret env` emits shell-quoted exports for declared secret keys only.
	_ms_exports=$(monosecret -f "$_ms_file" --reason "$_ms_reason" env --shell bash) || {
		unset _ms_reason _ms_file _ms_exports
		return 1
	}
	if eval "$_ms_exports"; then
		unset _ms_reason _ms_file _ms_exports
		return 0
	fi
	unset _ms_reason _ms_file _ms_exports
	return 1
}
