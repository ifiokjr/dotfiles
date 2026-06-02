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
#   2. If `.fvmrc` is absent    → skip
#   3. If directory is not allowed → skip (with hint in DOTFILES_DEBUG mode)
#   4. Remove any previous `.fvm/default/bin` from PATH
#   5. Prepend the current project's `.fvm/default/bin` to PATH

_FVM_ALLOW_FILE="${HOME}/.config/fvm/allowed-dirs"

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
		echo "Already allowed: $target"
		return 0
	fi

	printf '%s\n' "$target" >>"$_FVM_ALLOW_FILE"
	echo "Allowed FVM auto-load for: $target"
	# shellcheck disable=SC2034
	_fvm_previous_dir="" # force reactivation
	_fvm_auto_activate
}

fvm-deny() {
	local target
	target="$(cd "${1:-.}" && pwd)" || return 1

	if [ ! -f "$_FVM_ALLOW_FILE" ]; then
		echo "Not in allow list: $target" >&2
		return 1
	fi

	if ! grep -qxF "$target" "$_FVM_ALLOW_FILE" 2>/dev/null; then
		echo "Not in allow list: $target" >&2
		return 1
	fi

	local tmp
	tmp="$(mktemp)"
	grep -vxF "$target" "$_FVM_ALLOW_FILE" >"$tmp" 2>/dev/null || true
	cat "$tmp" >"$_FVM_ALLOW_FILE"
	rm -f "$tmp"

	# Remove matching fvm bin from PATH
	local fvm_bin="${target}/.fvm/default/bin"
	_fvm_remove_from_path "$fvm_bin"
	echo "Denied FVM auto-load for: $target"
}

fvm-allowed() {
	if [ ! -f "$_FVM_ALLOW_FILE" ]; then
		return 0
	fi
	local dirs
	# shellcheck disable=SC2034
	while IFS= read -r dirs; do
		[ -z "$dirs" ] && continue
		if [ -f "${dirs}/.fvmrc" ]; then
			printf '  \033[32m✓\033[0m %s\n' "$dirs"
		else
			printf '  \033[33m✗ no .fvmrc\033[0m %s\n' "$dirs"
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

# Remove all .fvm/default/bin entries from PATH
_fvm_remove_all_fvm_from_path() {
	local new_path=""
	local IFS=':'
	local p
	for p in $PATH; do
		case "$p" in
		*/.fvm/default/bin) ;;
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

	# Skip if no .fvmrc in current directory
	if [ ! -f ".fvmrc" ]; then
		# Clean up stale entries when leaving a project
		_fvm_remove_all_fvm_from_path
		return 0
	fi

	# Security gate: must be explicitly allowed
	if ! _fvm_is_allowed "$dir"; then
		[ -n "${DOTFILES_DEBUG:-}" ] && echo "fvm: .fvmrc found but directory not allowed. Run \`fvm-allow\` to trust it." >&2
		return 0
	fi

	local fvm_bin="${dir}/.fvm/default/bin"
	if [ ! -d "$fvm_bin" ]; then
		[ -n "${DOTFILES_DEBUG:-}" ] && echo "fvm: .fvm/bin not found — run \`fvm use\` in the project first" >&2
		return 0
	fi

	# Remove any previous .fvm/default/bin entries to avoid PATH pollution
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
	# Append to PROMPT_COMMAND without overwriting existing entries.
	_fvm_prompt_cmd="_fvm_cd_hook"
	case " ${PROMPT_COMMAND:-} " in
	*" $_fvm_prompt_cmd "*) ;;
	*) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }$_fvm_prompt_cmd" ;;
	esac
fi

# Zsh: hook into chpwd
if [ -n "${ZSH_VERSION:-}" ]; then
	#autoload -Uz add-zsh-hook
	#add-zsh-hook chpwd _fvm_cd_hook
	# Using chpwd_functions array (more portable, no autoload needed)
	chpwd_functions=("${chpwd_functions[@]}" _fvm_cd_hook)
fi
