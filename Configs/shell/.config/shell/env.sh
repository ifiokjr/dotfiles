#!/usr/bin/env bash

# env.sh - Shared environment configuration for bash/zsh
# POSIX-shell equivalent of nushell's env.nu
# Sourced by both ~/.bashrc and ~/.zshrc

# ---------------------------------------------------------------------------
# Nix bootstrap
# ---------------------------------------------------------------------------
# When nix-darwin's set-environment hasn't run (e.g. non-login shell, SSH),
# source the nix-daemon profile to get nix on PATH.
if [ -z "${__NIX_DARWIN_SET_ENVIRONMENT_DONE:-}" ]; then
	if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
		# shellcheck disable=SC1091
		. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
	fi
fi

# Ensure nix profile paths are on PATH (idempotent)
for _p in "$HOME/.nix-profile/bin" \
	"/etc/profiles/per-user/${USER}/bin" \
	"/run/current-system/sw/bin" \
	"/nix/var/nix/profiles/default/bin"; do
	# shellcheck disable=SC2249
	[ -d "$_p" ] && case ":$PATH:" in *":$_p:"*) ;; *) export PATH="$_p:$PATH" ;; esac
done
unset _p

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
export EDITOR="hx"
export SUDO_EDITOR="hx"

# ---------------------------------------------------------------------------
# macOS
# ---------------------------------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET="12.0"
ARCHFLAGS="-arch arm64"
export ARCHFLAGS

# ---------------------------------------------------------------------------
# File descriptor limit
# ---------------------------------------------------------------------------
# macOS default is 256 which causes "Too many open files" during nix builds,
# devenv, and heavy tool usage. Bump to a comfortable default.
# This is per-shell; the system-wide limit is set via launchd.daemons.limit-maxfiles
# in darwin.nix (soft: 65536, hard: 524288).
if [ "$(ulimit -n)" -lt 65536 ] 2>/dev/null; then
	ulimit -n 65536 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Deno
# ---------------------------------------------------------------------------
export DENO_INSTALL="$HOME/.deno"

# ---------------------------------------------------------------------------
# Android
# ---------------------------------------------------------------------------
export ANDROID_HOME="$HOME/Library/Android/sdk"
_ndk_base="$ANDROID_HOME/ndk"
if [ -d "$_ndk_base" ]; then
	# Pick the latest NDK version directory
	NDK_HOME=$(find "$_ndk_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)
	[ -z "$NDK_HOME" ] && NDK_HOME="$_ndk_base/29.0.13599879"
else
	NDK_HOME="$_ndk_base/29.0.13599879"
fi
export NDK_HOME
unset _ndk_base

# ---------------------------------------------------------------------------
# pnpm
# ---------------------------------------------------------------------------
export PNPM_HOME="$HOME/Library/pnpm"

# ---------------------------------------------------------------------------
# Docker compatibility via podman (macOS)
# ---------------------------------------------------------------------------
# Dynamically set DOCKER_HOST from the podman machine socket path.
# This enables Docker SDK clients (docker-py, Testcontainers, IronClaw) to
# connect to the podman VM. The `docker` CLI wrapper (exec podman) works without this.
if [ "$(uname)" = "Darwin" ] && command -v podman >/dev/null 2>&1; then
	_docker_host_sock=$(podman machine inspect podman-machine-default --format '{{.ConnectionInfo.PodmanSocket.Path}}' 2>/dev/null | tr -d '\n')
	if [ -n "$_docker_host_sock" ] && [ -S "$_docker_host_sock" ]; then
		export DOCKER_HOST="unix://${_docker_host_sock}"
	fi
	unset _docker_host_sock
fi

# ---------------------------------------------------------------------------
# GPG
# ---------------------------------------------------------------------------
GPG_TTY=$(tty 2>/dev/null || true)
export GPG_TTY

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------
export SOURCE_DATE_EPOCH="0"
export DIRENV_LOG_FORMAT=""

# ---------------------------------------------------------------------------
# PATH (single consolidation point)
# ---------------------------------------------------------------------------
# Prepend (high priority)
for _p in "$HOME/.local/bin" \
	"$HOME/.cargo/bin" \
	"$HOME/.shorebird/bin" \
	"${XDG_DATA_HOME:-$HOME/.local/share}/pnpm-global/node_modules/.bin" \
	"$PNPM_HOME/bin" \
	"$HOME/.local/share/solana/install/active_release/bin" \
	"$HOME/fvm/default/bin" \
	"$DENO_INSTALL/bin"; do
	# shellcheck disable=SC2249
	case ":$PATH:" in *":$_p:"*) ;; *) export PATH="$_p:$PATH" ;; esac
done

# Append (low priority)
for _p in "$ANDROID_HOME/cmdline-tools/latest/bin" \
	"$ANDROID_HOME/platform-tools" \
	"/Applications/Android Studio.app/Contents/MacOS" \
	"$HOME/.pub-cache/bin" \
	"/usr/local/bin"; do
	# shellcheck disable=SC2249
	case ":$PATH:" in *":$_p:"*) ;; *) export PATH="$PATH:$_p" ;; esac
done
unset _p

# ---------------------------------------------------------------------------
# OpenCode
# ---------------------------------------------------------------------------
# OpenCode 1 and the OpenCode 2 preview need mutually exclusive permission
# config: V1 reads the "permission" map in config.json, while V2 reads a
# "permissions" rule array from opencode.json. V1 refuses to start when it finds
# V2's key, and V2 ignores a config file that sits inside the directory it
# already scans, so V2 gets its own config directory instead of sharing
# ~/.config/opencode/. Keep the two directories separate.
opencode2() {
	OPENCODE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-v2" command opencode2 "$@"
}

# Source the unified agents configuration
if [ -f "$HOME/.config/agents/agents.env.sh" ]; then
	# shellcheck disable=SC1091
	. "$HOME/.config/agents/agents.env.sh"
fi

# ---------------------------------------------------------------------------
# pnpm global shortcut
# ---------------------------------------------------------------------------
# pnpmg runs pnpm against the Tuckr-managed global project, which lives in the
# dotfiles repo ($HOME/.config/pnpm-global resolves there). It deliberately
# avoids the runtime install directory at ${XDG_DATA_HOME:-$HOME/.local/share}/pnpm-global,
# whose manifests are symlinks back to the repo: pnpm 12 refuses to write a
# lockfile reached through a symlink (ERR_PNPM_LOCKFILE_WRITE_FILE), so
# manifest edits (add/remove/update) must run where the lockfile is a real file.
# Installing into the runtime directory stays with `pnpm:global:sync`, which
# keeps generated node_modules out of the repo.
pnpmg() { pnpm --dir "${XDG_CONFIG_HOME:-$HOME/.config}/pnpm-global" "$@"; }

# ---------------------------------------------------------------------------
# ZCode
# ---------------------------------------------------------------------------
# zcode runs the CLI bundled inside ZCode.app (macOS only). Arguments pass
# through untouched.
if [ "$(uname -s)" = "Darwin" ] && [ -x "/Applications/ZCode.app/Contents/Resources/glm/zcode.cjs" ]; then
	zcode() {
		"/Applications/ZCode.app/Contents/Resources/glm/zcode.cjs" "$@"
	}
fi

# ---------------------------------------------------------------------------
# Claude Desktop
# ---------------------------------------------------------------------------
# ccd opens a folder as a Claude Code session in Claude Desktop, the way
# `code .` opens one in VS Code. The `claude://code/new` deep link is the only
# reliable route: `open -na "Claude" --args <path>` drops its arguments because
# Electron's single-instance lock swallows them (anthropics/claude-code#54614).
# Desktop treats every link-supplied folder as untrusted and confirms it before
# adopting it as the working directory, even for folders trusted earlier.
#
# Hand-rolled percent-encoding instead of `python3 -c 'urllib.parse.quote'`:
# this file is sourced by non-interactive shells and on Linux, where python3 is
# not guaranteed to exist. Only unreserved characters (RFC 3986) stay literal,
# which matches Python's quote(safe="").
_ccd_urlenc() (
	LC_ALL=C
	s="$1"
	out=""
	while [ -n "$s" ]; do
		c="${s%"${s#?}"}"
		s="${s#?}"
		case "$c" in
		[a-zA-Z0-9.~_-]) out="$out$c" ;;
		*) out="$out$(printf '%%%02X' "'$c")" ;;
		esac
	done
	printf '%s' "$out"
)

ccd() {
	local dir opener
	# Resolve through cd+pwd so a bad argument fails loudly instead of opening
	# Desktop in whatever directory happened to be current.
	dir="$(cd -- "${1:-.}" 2>/dev/null && pwd)" || {
		printf 'ccd: not a directory: %s\n' "${1:-.}" >&2
		return 1
	}
	if [ "$(uname -s)" = "Darwin" ]; then
		opener=open
	else
		opener=xdg-open
	fi
	"$opener" "claude://code/new?folder=$(_ccd_urlenc "$dir")"
}

# FVM auto-switching (allow-gated)
if [ -f "$HOME/.config/shell/fvm.sh" ]; then
	# shellcheck disable=SC1091
	. "$HOME/.config/shell/fvm.sh"
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias ds='devenv shell'
alias de='devenv up'

# ---------------------------------------------------------------------------
# Secrets — 1Password-backed via Monosecret, no plaintext on disk
# ---------------------------------------------------------------------------
if [ -f "$HOME/.config/shell/secrets.sh" ]; then
	# shellcheck disable=SC1091
	. "$HOME/.config/shell/secrets.sh"
fi

# ---------------------------------------------------------------------------
# Codex API Keys
# ---------------------------------------------------------------------------
# Load API keys for custom Codex providers (Xiaomi MiMo, Ollama Cloud)
# Primary source: 1Password via Monosecret (use `msr --reason "<why>" codex ...`)
# Fallback: ~/.codex/secrets.env for offline use
if [ -f ~/.codex/secrets.env ]; then
	XIAOMI_MIMO_API_KEY=$(grep '^XIAOMI_MIMO_API_KEY=' ~/.codex/secrets.env | cut -d'=' -f2)
	OLLAMA_CLOUD_API_KEY=$(grep '^OLLAMA_CLOUD_API_KEY=' ~/.codex/secrets.env | cut -d'=' -f2)
	OLLAMA_API_KEY=$(grep '^OLLAMA_API_KEY=' ~/.codex/secrets.env | cut -d'=' -f2-)
	export XIAOMI_MIMO_API_KEY OLLAMA_CLOUD_API_KEY OLLAMA_API_KEY
fi
