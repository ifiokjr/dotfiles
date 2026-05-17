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
	"$HOME/.config/pnpm-global/node_modules/.bin" \
	"$PNPM_HOME" \
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
# Deprecated: These environment variables are now managed via the 'agents' config group
# See: Configs/agents/.config/agents/agents.env.sh
# Kept here temporarily for backward compatibility during transition
export OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS=true
export OPENCODE_ALLOW_ALL_BASH=true
export OPENCODE_TRUSTED_DIRECTORIES="/Users/ifiokjr/Developer,/tmp"

# Source the unified agents configuration (overrides above if present)
if [ -f "$HOME/.config/agents/agents.env.sh" ]; then
	# shellcheck disable=SC1091
	. "$HOME/.config/agents/agents.env.sh"
fi

# ---------------------------------------------------------------------------
# Secrets (optional, not committed)
# ---------------------------------------------------------------------------
if [ -f "$HOME/.env.dotfiles" ]; then
	set -a
	# shellcheck disable=SC1091
	. "$HOME/.env.dotfiles"
	set +a
fi
