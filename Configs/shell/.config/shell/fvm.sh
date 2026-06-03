#!/usr/bin/env bash
# fvm.sh — FVM per-project Flutter/Dart auto-switching with allow-gate security
#
# Security model (like direnv's `direnv allow`):
#   Auto-loading only activates for directories explicitly allowed by the user.
#   This prevents malicious `.fvmrc` files from injecting binaries via PATH.
#
# Commands:
#   fvm-allow         — Trust the current project directory for FVM auto-loading
#   fvm-deny          — Revoke trust for the current (or specified) directory
#   fvm-allowed       — List all trusted directories
#
# The cd hook (PROMPT_COMMAND / chpwd) runs on every directory change:
#   1. If fvm is not installed → skip
#   2. If `.fvmrc` is absent    → clean up any stale entries, skip
#   3. If directory is not allowed → skip (with hint to run `fvm-allow`)
#   4. Remove any previous `.fvm/flutter_sdk/bin` from PATH
#   5. Prepend the current project's `.fvm/flutter_sdk/bin` to PATH

_FVM_ALLOW_FILE="${HOME}/.config/fvm/allowed-dirs"

# Track which directories have already shown the allow-hint this session
# so we don't spam on every prompt.
_FVM_HINT_SHOWN=""

# ---------------------------------------------------------------------------
# Allow / deny commands
# ---------------------------------------------------------------------------

fvm-allow() {
	local target
	target="$(cd "${1:-.}" && pwd)" || return 1

	if [ ! -f "${target}/.fvmrc" ]; then
		echo "No .fvmrc found in ${target}" >&2
		return 1
	fi

	mkdir -p "$(_fvm_allow_dir)"
	touch "$_FVM_ALLOW_FILE"

	if grep -qxF "$target" "$_FVM_ALLOW_FILE" 2>/dev/null; then
		printf '\033[32mAlready allowed:\033[0m %s\n' "$target"
	else
		printf '%s\n' "$target" >>"$_FVM_ALLOW_FILE"
		printf '\033[32mAllowed FVM auto-load for:\033[0m %s\n' "$target"
	fi

	# Activate immediately — no need to cd out and back in
	# Per-project fvm uses `.fvm/flutter_sdk/bin`; global uses `~/fvm/default/bin`
	local fvm_bin="${target}/.fvm/flutter_sdk/bin"
	_fvm_remove_all_fvm_from_path
	if [ -d "$fvm_bin" ]; then
		export PATH="${fvm_bin}:${PATH}"
		printf '\033[32mActivated:\033[0m %s is on PATH\n' "$fvm_bin"
	else
		# shellcheck disable=SC2016
		printf '\033[33mfvm bin not found at %s — run `fvm use` first\033[0m\n' "$fvm_bin"
	fi

	# Clear hint cache since this dir is now allowed
	_FVM_HINT_SHOWN=""
}

fvm-deny() {
	local target
	target="$(cd "${1:-.}" && pwd)" || return 1

	if [ ! -f "$_FVM_ALLOW_FILE" ]; then
		printf '\033[33mNot in allow list:\033[0m %s\n' "$target" >&2
		return 1
	fi

	if ! grep -qxF "$target" "$_FVM_ALLOW_FILE" 2>/dev/null; then
		printf '\033[33mNot in allow list:\033[0m %s\n' "$target" >&2
		return 1
	fi

	local tmp
	tmp="$(mktemp)"
	grep -vxF "$target" "$_FVM_ALLOW_FILE" >"$tmp" 2>/dev/null || true
	cat "$tmp" >"$_FVM_ALLOW_FILE"
	rm -f "$tmp"

	# Remove matching fvm bin from PATH
	_fvm_remove_all_fvm_from_path
	printf '\033[31mDenied FVM auto-load for:\033[0m %s\n' "$target"
}

fvm-allowed() {
	if [ ! -f "$_FVM_ALLOW_FILE" ]; then
		return 0
	fi
	local dir
	while IFS= read -r dir; do
		[ -z "$dir" ] && continue
		if [ -f "${dir}/.fvmrc" ]; then
			printf '  \033[32m✓\033[0m %s\n' "$dir"
		else
			printf '  \033[33m✗ no .fvmrc\033[0m %s\n' "$dir"
		fi
	done <"$_FVM_ALLOW_FILE"
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_fvm_allow_dir() {
	dirname "$_FVM_ALLOW_FILE"
}

_fvm_is_allowed() {
	local dir="$1"
	[ -f "$_FVM_ALLOW_FILE" ] && grep -qxF "$dir" "$_FVM_ALLOW_FILE" 2>/dev/null
}

# Remove a specific path from PATH (in-place)
_fvm_remove_from_path() {
	local target="$1"
	local new_path=""
	local IFS=':'
	local p
	for p in $PATH; do
		if [ "$p" != "$target" ]; then
			new_path="${new_path:+$new_path:}$p"
		fi
	done
	[ "$new_path" != "$PATH" ] && export PATH="$new_path"
}

# Remove all .fvm/flutter_sdk/bin entries from PATH
_fvm_remove_all_fvm_from_path() {
	local new_path=""
	local IFS=':'
	local p
	for p in $PATH; do
		case "$p" in
		*/.fvm/flutter_sdk/bin) ;;
		*) new_path="${new_path:+$new_path:}$p" ;;
		esac
	done
	export PATH="$new_path"
}

_fvm_auto_activate() {
	# Skip if fvm is not installed
	command -v fvm >/dev/null 2>&1 || return 0

	local dir
	dir="$(pwd -P)" || return 0

	# No .fvmrc in current directory — leaving a project, clean up
	if [ ! -f ".fvmrc" ]; then
		_fvm_remove_all_fvm_from_path
		return 0
	fi

	# Security gate: must be explicitly allowed
	if ! _fvm_is_allowed "$dir"; then
		# Only show the hint once per directory per session
		case " $_FVM_HINT_SHOWN " in
		*" $dir "*) ;;
		*)
			printf '\033[33mfvm: .fvmrc found — run \033[1mfvm-allow\033[0m\033[33m to trust this project\033[0m\n'
			_FVM_HINT_SHOWN="${_FVM_HINT_SHOWN:+$FVM_HINT_SHOWN }$dir"
			;;
		esac
		return 0
	fi

	# Per-project fvm uses `.fvm/flutter_sdk/bin`; global uses `~/fvm/default/bin`
	local fvm_bin="${dir}/.fvm/flutter_sdk/bin"
	if [ ! -d "$fvm_bin" ]; then
		# shellcheck disable=SC2016
		[ -n "${DOTFILES_DEBUG:-}" ] && printf 'fvm: .fvm/flutter_sdk/bin not found — run `fvm use` in the project first\n' >&2
		return 0
	fi

	# Remove any previous .fvm/flutter_sdk/bin entries to avoid PATH pollution
	_fvm_remove_all_fvm_from_path

	# Prepend the project's fvm bin
	export PATH="${fvm_bin}:${PATH}"
}

# ---------------------------------------------------------------------------
# Shell hooks (bash / zsh)
# ---------------------------------------------------------------------------

# Track previous directory to avoid re-running on every PROMPT_COMMAND
# when the directory hasn't actually changed.
_fvm_previous_dir=""

_fvm_cd_hook() {
	local current
	current="$(pwd -P)" || return 0
	[ "$current" = "$_fvm_previous_dir" ] && return 0
	_fvm_previous_dir="$current"
	_fvm_auto_activate
}

# Bash: hook into PROMPT_COMMAND
if [ -n "${BASH_VERSION:-}" ]; then
	_fvm_prompt_cmd="_fvm_cd_hook"
	case " ${PROMPT_COMMAND:-} " in
	*" $_fvm_prompt_cmd "*) ;;
	*) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }$_fvm_prompt_cmd" ;;
	esac
fi

# Zsh: hook into chpwd
if [ -n "${ZSH_VERSION:-}" ]; then
	chpwd_functions=("${chpwd_functions[@]}" _fvm_cd_hook)
fi
