#!/usr/bin/env bash

# android.sh - Android SDK environment for bash/zsh
# Sourced by env.sh (interactive shells) and ~/.zshenv (every zsh shell,
# including the non-interactive ones agents and scripts use), so it must stay
# cheap and idempotent. POSIX-shell equivalent of the Android block in env.nu.

export ANDROID_HOME="$HOME/Library/Android/sdk"

# nix-darwin sets XDG_CONFIG_HOME, which makes sdkmanager, avdmanager, and
# Gradle keep their state (AVDs, debug.keystore) in $XDG_CONFIG_HOME/.android,
# while the emulator and adb still look in ~/.android and cannot find the AVDs
# avdmanager creates. ANDROID_USER_HOME points the SDK tools at one place, and
# the emulator needs ANDROID_AVD_HOME too: it ignores ANDROID_USER_HOME when
# listing and launching AVDs.
if [ -n "${XDG_CONFIG_HOME:-}" ]; then
	export ANDROID_USER_HOME="$XDG_CONFIG_HOME/.android"
else
	export ANDROID_USER_HOME="$HOME/.android"
fi
export ANDROID_AVD_HOME="$ANDROID_USER_HOME/avd"

# Pick the latest NDK version directory. Child shells inherit NDK_HOME, so
# only the first shell pays for the lookup.
if [ -z "${NDK_HOME:-}" ]; then
	_ndk_base="$ANDROID_HOME/ndk"
	if [ -d "$_ndk_base" ]; then
		NDK_HOME=$(find "$_ndk_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)
		[ -z "$NDK_HOME" ] && NDK_HOME="$_ndk_base/29.0.13599879"
	else
		NDK_HOME="$_ndk_base/29.0.13599879"
	fi
	export NDK_HOME
	unset _ndk_base
fi

# Append (low priority)
for _p in "$ANDROID_HOME/cmdline-tools/latest/bin" \
	"$ANDROID_HOME/platform-tools" \
	"$ANDROID_HOME/emulator" \
	"/Applications/Android Studio.app/Contents/MacOS"; do
	# shellcheck disable=SC2249
	case ":$PATH:" in *":$_p:"*) ;; *) export PATH="$PATH:$_p" ;; esac
done
unset _p
