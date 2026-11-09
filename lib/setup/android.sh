#!/usr/bin/env bash

# Android SDK provisioning for setup.
#
# The Android SDK is user state under ~/Library/Android/sdk, not a Nix package:
# T3 Code's Device panel, Android Studio, Gradle, and the managed shell
# environment all expect that path. This phase keeps it populated for macOS
# desktop machines that act as connected-device hosts.
#
# The command-line tools zip is pinned to a Google release and verified by
# SHA-256 before it is unpacked. Package coordinates pin the platform, build
# tools, and NDK; platform-tools and the emulator track Google's current
# release because those are the components the device host launches.

ANDROID_CMDLINE_TOOLS_VERSION="23.0"
ANDROID_CMDLINE_TOOLS_BUILD="16111833"
ANDROID_CMDLINE_TOOLS_SHA256_ARM64="58da8f215781cc0208743e88b65ae259780c55e7eb40e50373d377cf369232d6"
ANDROID_CMDLINE_TOOLS_SHA256_X86_64="7e601c04e7173754b3d051a87bb4c3a8243c65a9d7bfa9356ed6499fb8953fa3"
ANDROID_SDK_PLATFORM="android-36"
ANDROID_SDK_BUILD_TOOLS="36.1.0"
ANDROID_SDK_NDK="28.2.13676358"
ANDROID_SDK_SYSTEM_IMAGE_TAG="google_apis"
ANDROID_SDK_AVD_NAME="dotfiles_pixel_8"

android_sdk_root() {
	printf '%s\n' "${ANDROID_HOME:-$HOME/Library/Android/sdk}"
}

android_sdk_arch() {
	case "$(uname -m)" in
	arm64 | aarch64)
		printf 'arm64\n'
		;;
	x86_64 | amd64)
		printf 'x86_64\n'
		;;
	*)
		return 1
		;;
	esac
}

android_sdk_abi() {
	case "$(android_sdk_arch)" in
	arm64)
		printf 'arm64-v8a\n'
		;;
	x86_64)
		printf 'x86_64\n'
		;;
	esac
}

android_sdk_cmdline_tools_sha256() {
	case "$(android_sdk_arch)" in
	arm64)
		printf '%s\n' "$ANDROID_CMDLINE_TOOLS_SHA256_ARM64"
		;;
	x86_64)
		printf '%s\n' "$ANDROID_CMDLINE_TOOLS_SHA256_X86_64"
		;;
	esac
}

# Provision by default only on macOS desktops. The mini fleet is lite mode
# (so GUI casks are skipped) but isDesktop/alwaysOn is exactly what makes it a
# connected-device host. CI runners have no machine.nix and stay opted out.
android_sdk_should_install() {
	if [ "${PLATFORM:-}" != "macos" ]; then
		return 1
	fi

	case "${ANDROID_SDK_MODE:-auto}" in
	true)
		return 0
		;;
	false)
		return 1
		;;
	esac

	if [ "${SETUP_DESKTOP:-false}" = "true" ] || [ "${SETUP_ALWAYS_ON:-false}" = "true" ]; then
		return 0
	fi

	local machine_nix="${MACHINE_NIX_FILE:-$HOME/.config/nix/machine.nix}"
	if [ -f "$machine_nix" ] &&
		grep -Eq '^[[:space:]]*(isDesktop|alwaysOn)[[:space:]]*=[[:space:]]*true[[:space:]]*;' "$machine_nix"; then
		return 0
	fi

	return 1
}

plan_android_sdk_action() {
	if [ "${PLATFORM:-}" != "macos" ]; then
		printf 'skip (macOS only)\n'
		return 0
	fi

	case "${ANDROID_SDK_MODE:-auto}" in
	false)
		printf 'skip (--no-android-sdk)\n'
		return 0
		;;
	true) ;;
	*)
		if ! android_sdk_should_install; then
			printf 'skip (not a desktop machine)\n'
			return 0
		fi
		;;
	esac

	printf 'ensure SDK and emulator AVD at %s\n' "$(android_sdk_root)"
}

android_sdk_has_avd() {
	local avd_home="$1"
	[ -d "$avd_home" ] &&
		[ -n "$(find "$avd_home" -maxdepth 1 -name '*.ini' -type f -print -quit 2> /dev/null)" ]
}

# AVDs created before the XDG-aware shell environment landed live in
# ~/.android/avd. Prefer any populated home so setup and the emulator agree,
# then fall back to the legacy location that T3 Code's device host inspects.
android_sdk_avd_home() {
	local xdg_avd
	xdg_avd="${ANDROID_USER_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/.android}/avd"

	if [ -n "${ANDROID_AVD_HOME:-}" ] && android_sdk_has_avd "$ANDROID_AVD_HOME"; then
		printf '%s\n' "$ANDROID_AVD_HOME"
		return 0
	fi
	if android_sdk_has_avd "$HOME/.android/avd"; then
		printf '%s\n' "$HOME/.android/avd"
		return 0
	fi
	if android_sdk_has_avd "$xdg_avd"; then
		printf '%s\n' "$xdg_avd"
		return 0
	fi

	printf '%s\n' "$HOME/.android/avd"
}

android_sdk_download_cmdline_tools() {
	local sdk_root="$1"
	local arch expected actual tmp_dir url

	arch="$(android_sdk_arch)" || {
		print_error "Unsupported macOS architecture: $(uname -m)"
		return 1
	}
	expected="$(android_sdk_cmdline_tools_sha256)"
	url="https://dl.google.com/android/repository/commandlinetools-mac_${arch}-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"

	tmp_dir="$(mktemp -d)"
	print_info "Downloading Android command-line tools ${ANDROID_CMDLINE_TOOLS_VERSION} (pinned, sha256-verified)..."
	if ! curl -fsSL -o "$tmp_dir/cmdline-tools.zip" "$url"; then
		print_error "Failed to download Android command-line tools from $url"
		rm -rf "$tmp_dir"
		return 1
	fi

	if command -v sha256sum > /dev/null 2>&1; then
		actual="$(sha256sum "$tmp_dir/cmdline-tools.zip" | awk '{print $1}')"
	else
		actual="$(shasum -a 256 "$tmp_dir/cmdline-tools.zip" | awk '{print $1}')"
	fi
	if [ "$actual" != "$expected" ]; then
		print_error "Android command-line tools checksum mismatch: expected $expected, got $actual"
		rm -rf "$tmp_dir"
		return 1
	fi

	if ! unzip -q "$tmp_dir/cmdline-tools.zip" -d "$tmp_dir/unpacked"; then
		print_error "Failed to unpack the Android command-line tools archive"
		rm -rf "$tmp_dir"
		return 1
	fi

	mkdir -p "$sdk_root/cmdline-tools"
	rm -rf "$sdk_root/cmdline-tools/latest"
	mv "$tmp_dir/unpacked/cmdline-tools" "$sdk_root/cmdline-tools/latest"
	rm -rf "$tmp_dir"
}

android_sdk_packages_present() {
	local sdk_root="$1"
	local abi="$2"

	[ -x "$sdk_root/cmdline-tools/latest/bin/sdkmanager" ] &&
		[ -x "$sdk_root/platform-tools/adb" ] &&
		[ -x "$sdk_root/emulator/emulator" ] &&
		[ -d "$sdk_root/platforms/$ANDROID_SDK_PLATFORM" ] &&
		[ -d "$sdk_root/build-tools/$ANDROID_SDK_BUILD_TOOLS" ] &&
		[ -d "$sdk_root/ndk/$ANDROID_SDK_NDK" ] &&
		[ -d "$sdk_root/system-images/$ANDROID_SDK_PLATFORM/$ANDROID_SDK_SYSTEM_IMAGE_TAG/$abi" ]
}

android_sdk_accept_licenses() {
	local sdkmanager="$1"
	local sdk_root="$2"

	print_info "Accepting Android SDK licenses..."
	# sdkmanager reads license answers from stdin. `yes` exits on SIGPIPE when
	# sdkmanager closes the pipe, so temporarily disable pipefail around it.
	set +o pipefail
	yes | "$sdkmanager" --sdk_root="$sdk_root" --licenses > /dev/null 2>&1 || true
	set -o pipefail
}

android_sdk_install_packages() {
	local sdkmanager="$1"
	local sdk_root="$2"
	local abi="$3"
	local packages=(
		"platform-tools"
		"emulator"
		"platforms;$ANDROID_SDK_PLATFORM"
		"build-tools;$ANDROID_SDK_BUILD_TOOLS"
		"ndk;$ANDROID_SDK_NDK"
		"system-images;$ANDROID_SDK_PLATFORM;$ANDROID_SDK_SYSTEM_IMAGE_TAG;$abi"
	)

	print_info "Installing Android SDK packages: ${packages[*]}"
	if ! "$sdkmanager" --sdk_root="$sdk_root" --install "${packages[@]}"; then
		print_error "Android SDK package installation failed"
		return 1
	fi
}

android_sdk_ensure_avd() {
	local sdk_root="$1"
	local abi="$2"
	local avdmanager avd_home

	avd_home="$(android_sdk_avd_home)"
	if android_sdk_has_avd "$avd_home"; then
		print_info "Android emulator AVD already present in $avd_home"
		return 0
	fi

	avdmanager="$sdk_root/cmdline-tools/latest/bin/avdmanager"
	if [ ! -x "$avdmanager" ]; then
		print_error "avdmanager not found at $avdmanager"
		return 1
	fi

	mkdir -p "$avd_home"
	print_info "Creating Android emulator AVD '$ANDROID_SDK_AVD_NAME'..."
	if ! printf 'no\n' |
		ANDROID_AVD_HOME="$avd_home" \
		ANDROID_USER_HOME="$(dirname "$avd_home")" \
		"$avdmanager" create avd \
		--name "$ANDROID_SDK_AVD_NAME" \
		--package "system-images;$ANDROID_SDK_PLATFORM;$ANDROID_SDK_SYSTEM_IMAGE_TAG;$abi" \
		--device pixel_8 \
		--force; then
		print_warning "Could not create the Android emulator AVD automatically"
		return 1
	fi
}

install_android_sdk() {
	local sdk_root abi sdkmanager

	sdk_root="$(android_sdk_root)"
	abi="$(android_sdk_abi)" || {
		print_error "Unsupported macOS architecture: $(uname -m)"
		return 1
	}

	print_header "Provisioning Android SDK"

	if ! command -v java > /dev/null 2>&1; then
		print_error "Java is required to run sdkmanager"
		print_info "Deploy the nix group (which installs jdk) and retry this phase"
		return 1
	fi

	mkdir -p "$sdk_root"
	export ANDROID_HOME="$sdk_root"
	export ANDROID_SDK_ROOT="$sdk_root"

	if [ ! -x "$sdk_root/cmdline-tools/latest/bin/sdkmanager" ]; then
		android_sdk_download_cmdline_tools "$sdk_root" || return 1
	fi
	sdkmanager="$sdk_root/cmdline-tools/latest/bin/sdkmanager"

	if android_sdk_packages_present "$sdk_root" "$abi"; then
		print_success "Android SDK packages already installed"
	else
		android_sdk_accept_licenses "$sdkmanager" "$sdk_root"
		android_sdk_install_packages "$sdkmanager" "$sdk_root" "$abi" || return 1
	fi

	android_sdk_ensure_avd "$sdk_root" "$abi" || return 1

	print_success "Android SDK ready at $sdk_root"
	print_info "Enable Agent device access in T3 Code (Settings > Integrations > Devices) to expose AVDs from $(android_sdk_avd_home) in the Device panel"
}
