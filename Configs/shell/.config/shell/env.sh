#!/usr/bin/env bash
# env.sh - Shared environment for bash and zsh
#
# Mirrors the environment from nushell's env.nu so all shells have
# identical PATH, env vars, and nix bootstrap. Sourced by .bashrc/.zshrc.

# ---------------------------------------------------------------------------
# Nix bootstrap
# ---------------------------------------------------------------------------
# Source nix-daemon profile if available (sets NIX_PROFILES, PATH, etc.)
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
	# shellcheck disable=SC1091
	. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# When nix env vars are missing (e.g. login shell before nix-daemon profile
# has run), detect and set them manually — mirrors nushell env.nu logic.
if [ -z "$NIX_PROFILES" ]; then
	_user="${USER:-$(whoami)}"
	export NIX_PROFILES="/nix/var/nix/profiles/default /run/current-system/sw /etc/profiles/per-user/$_user $HOME/.nix-profile"
	export NIX_USER_PROFILE_DIR="/nix/var/nix/profiles/per-user/$_user"
	export NIX_SSL_CERT_FILE="/etc/ssl/certs/ca-certificates.crt"
	export __NIX_DARWIN_SET_ENVIRONMENT_DONE="1"
	export TERMINFO_DIRS="$HOME/.nix-profile/share/terminfo:/etc/profiles/per-user/$_user/share/terminfo:/run/current-system/sw/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo"
	export XDG_CONFIG_HOME="$HOME/.config"
	export XDG_CONFIG_DIRS="$HOME/.nix-profile/etc/xdg:/etc/profiles/per-user/$_user/etc/xdg:/run/current-system/sw/etc/xdg:/nix/var/nix/profiles/default/etc/xdg"
	export XDG_DATA_DIRS="$HOME/.nix-profile/share:/etc/profiles/per-user/$_user/share:/run/current-system/sw/share:/nix/var/nix/profiles/default/share"

	# Nix PATH entries (matches nix-darwin set-environment order)
	for _p in \
		"/nix/var/nix/profiles/default/bin" \
		"/run/current-system/sw/bin" \
		"/etc/profiles/per-user/$_user/bin" \
		"$HOME/.nix-profile/bin"; do
		case ":$PATH:" in
		*":$_p:"*) ;;
		*) PATH="$_p:$PATH" ;;
		esac
	done
	unset _user _p
fi

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
export EDITOR="hx"
export SUDO_EDITOR="hx"

# ---------------------------------------------------------------------------
# macOS
# ---------------------------------------------------------------------------
export MACOSX_DEPLOYMENT_TARGET="12.0"
ARCHFLAGS="-arch $(uname -m)"
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
	_latest_ndk=$(find "$_ndk_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)
	NDK_HOME="$_latest_ndk"
else
	NDK_HOME="$_ndk_base/29.0.13599879"
fi
export NDK_HOME
unset _ndk_base _latest_ndk

# ---------------------------------------------------------------------------
# pnpm
# ---------------------------------------------------------------------------
export PNPM_HOME="$HOME/Library/pnpm"

# ---------------------------------------------------------------------------
# GPG
# ---------------------------------------------------------------------------
GPG_TTY=$(tty 2>/dev/null || echo "")
export GPG_TTY

# ---------------------------------------------------------------------------
# Carapace
# ---------------------------------------------------------------------------
export CARAPACE_BRIDGES="zsh,fish,bash,inshellisense"

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------
export SOURCE_DATE_EPOCH="0"
export DIRENV_LOG_FORMAT=""

# ---------------------------------------------------------------------------
# PATH (single consolidation point — mirrors nushell env.nu)
# ---------------------------------------------------------------------------
# Prepend paths (higher priority)
for _p in \
	"$DENO_INSTALL/bin" \
	"$HOME/fvm/default/bin" \
	"$HOME/.local/share/solana/install/active_release/bin" \
	"$PNPM_HOME" \
	"$HOME/.shorebird/bin" \
	"$HOME/.cargo/bin" \
	"$HOME/.local/bin"; do
	case ":$PATH:" in
	*":$_p:"*) ;;
	*) PATH="$_p:$PATH" ;;
	esac
done

# Append paths (lower priority)
for _p in \
	"$ANDROID_HOME/cmdline-tools/latest/bin" \
	"$ANDROID_HOME/platform-tools" \
	"/Applications/Android Studio.app/Contents/MacOS" \
	"$HOME/.pub-cache/bin" \
	"/usr/local/bin"; do
	case ":$PATH:" in
	*":$_p:"*) ;;
	*) PATH="$PATH:$_p" ;;
	esac
done

export PATH
unset _p

# ---------------------------------------------------------------------------
# Secrets - load KEY=VALUE pairs from ~/.env.dotfiles
# ---------------------------------------------------------------------------
load_dotfiles_secrets() {
	local secrets_file="$HOME/.env.dotfiles"
	[ -f "$secrets_file" ] || return 0
	while IFS= read -r line || [ -n "$line" ]; do
		# Skip comments and blank lines
		case "$line" in
		\#* | "") continue ;;
		esac
		# Only process lines with = sign
		case "$line" in
		*=*)
			local key="${line%%=*}"
			local value="${line#*=}"
			# Strip surrounding quotes
			value="${value#\"}"
			value="${value%\"}"
			value="${value#\'}"
			value="${value%\'}"
			export "$key=$value"
			;;
		esac
	done <"$secrets_file"
}
