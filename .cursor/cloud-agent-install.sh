#!/usr/bin/env bash
# Idempotent toolchain for Cursor cloud agents.
#
# Installs the same pinned Determinate Nix installer as ./setup, then the
# Linux CI tools from the nixpkgs revision locked in the Nix flake. Binaries
# are symlinked into /usr/local/bin so login and non-login shells both see
# them (cloud agent install/start are login shells, ad-hoc commands often
# are not, and Ubuntu's ~/.bashrc returns early when non-interactive).
#
# Racket is intentionally omitted. CI installs it only to run `raco fmt
# --help`; no check invokes it, and the package is large.
#
# macOS home-manager activation, `dot rebuild`, and the iOS/Android SDK
# provisioning in setup are not part of this install. They need a Mac.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

FLAKE_LOCK="$REPO_ROOT/Configs/nix/.config/nix/flake.lock"

# Keep these names aligned with `pkgs` in ci-lint-tools, plus the tools the
# other Linux CI jobs install (gitleaks, deno). The binary name differs for
# nushell.
PACKAGES=(
	shellcheck
	dprint
	nushell
	shfmt
	nixfmt
	kdlfmt
	nufmt
	taplo
	gitleaks
	deno
)

log() {
	printf '==> %s\n' "$*"
}

# Read ${VAR:-default} from setup so the installer pin cannot drift.
pinned_default() {
	local var="$1"
	local line value
	line="$(grep -E "\\$\\{${var}:-" "$REPO_ROOT/setup" | head -n 1 || true)"
	if [ -z "$line" ]; then
		printf 'could not read %s from setup\n' "$var" >&2
		exit 1
	fi
	value="${line#*"\${${var}:-"}"
	value="${value%%\}*}"
	value="${value%\"}"
	value="${value#\"}"
	printf '%s' "$value"
}

need_apt_packages() {
	local missing=0
	local cmd
	for cmd in curl git xz sha256sum sudo; do
		if ! command -v "$cmd" >/dev/null 2>&1; then
			missing=1
		fi
	done
	[ "$missing" -eq 1 ]
}

install_apt_packages() {
	if ! need_apt_packages; then
		return 0
	fi
	log "Installing base packages (curl, git, xz)"
	sudo DEBIAN_FRONTEND=noninteractive apt-get update
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		ca-certificates curl git xz-utils sudo
}

source_nix() {
	if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
		# shellcheck disable=SC1091
		. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
	fi
	if [ -d "$HOME/.nix-profile/bin" ]; then
		export PATH="$HOME/.nix-profile/bin:$PATH"
	fi
}

# `--init none` installs Nix without a service manager. The daemon has to be
# running before any client command; cloud agent `start` launches it on boot,
# and install launches it here because builds do not run `start`.
ensure_nix_daemon() {
	source_nix
	local nix_bin="/nix/var/nix/profiles/default/bin/nix"
	local daemon_bin="/nix/var/nix/profiles/default/bin/nix-daemon"
	local socket="/nix/var/nix/daemon-socket/socket"
	if [ ! -x "$daemon_bin" ]; then
		printf 'Nix daemon binary is missing\n' >&2
		exit 1
	fi
	if "$nix_bin" store ping >/dev/null 2>&1; then
		return 0
	fi
	if [ -S "$socket" ]; then
		sudo rm -f "$socket"
	fi
	log "Starting Nix daemon"
	# The redirect stays outside sudo on purpose: the log should be owned by
	# the agent user, not root. sudo applies only to the daemon process.
	# shellcheck disable=SC2024
	sudo "$daemon_bin" >/tmp/nix-daemon.log 2>&1 &
	local _i
	for _i in $(seq 1 50); do
		if "$nix_bin" store ping >/dev/null 2>&1; then
			return 0
		fi
		sleep 0.2
	done
	printf 'Nix daemon did not become ready\n' >&2
	cat /tmp/nix-daemon.log >&2 || true
	exit 1
}

install_nix() {
	source_nix
	if command -v nix >/dev/null 2>&1; then
		log "Nix already installed ($(nix --version))"
		ensure_nix_daemon
		return 0
	fi

	local url sha script actual
	url="${NIX_INSTALLER_URL:-$(pinned_default NIX_INSTALLER_URL)}"
	sha="${NIX_INSTALLER_SHA256:-$(pinned_default NIX_INSTALLER_SHA256)}"
	case "$url" in
	https://github.com/DeterminateSystems/nix-installer/releases/download/*/nix-installer.sh) ;;
	*)
		printf 'refusing unpinned Nix installer URL: %s\n' "$url" >&2
		exit 1
		;;
	esac
	if ! printf '%s' "$sha" | grep -Eq '^[0-9a-f]{64}$'; then
		printf 'refusing Nix installer checksum that is not 64 hex chars\n' >&2
		exit 1
	fi

	log "Downloading pinned Determinate Nix installer"
	script="$(mktemp)"
	if ! curl -fsSL -o "$script" "$url"; then
		rm -f "$script"
		printf 'failed to download %s\n' "$url" >&2
		exit 1
	fi
	actual="$(sha256sum "$script" | awk '{print $1}')"
	if [ "$actual" != "$sha" ]; then
		rm -f "$script"
		printf 'Nix installer checksum mismatch: expected %s, got %s\n' "$sha" "$actual" >&2
		exit 1
	fi

	local -a args=(install)
	# This VM has no systemd. Match ./setup: a root Nix install with no daemon.
	if [ "$(uname -s)" = "Linux" ] && [ ! -d /run/systemd/system ]; then
		args+=(linux --init none)
	fi
	args+=(--no-confirm)

	log "Installing Determinate Nix"
	if ! sh "$script" "${args[@]}"; then
		rm -f "$script"
		printf 'Nix installer failed\n' >&2
		exit 1
	fi
	rm -f "$script"
	source_nix
	if ! command -v nix >/dev/null 2>&1; then
		printf 'Nix installer finished but nix is not on PATH\n' >&2
		exit 1
	fi
	ensure_nix_daemon
}

nixpkgs_rev() {
	jq -er '
		.nodes.root.inputs.nixpkgs as $name
		| .nodes[$name].locked
		| select(.owner == "NixOS" and .repo == "nixpkgs" and .type == "github")
		| .rev
	' "$FLAKE_LOCK"
}

# `grep -q` closes the pipe early, and with `pipefail` that SIGPIPE makes
# `nix profile list` look like a miss even when the attribute is present.
profile_listing() {
	nix profile list 2>/dev/null || true
}

profile_has() {
	local listing="$1"
	local attr="$2"
	printf '%s\n' "$listing" | grep -Fq "$attr"
}

install_tools() {
	local rev installable
	rev="$(nixpkgs_rev)"
	installable="github:NixOS/nixpkgs/${rev}"
	log "Installing CI tools from nixpkgs ${rev}"

	# A token in the environment raises the GitHub rate limit for the nixpkgs
	# tarball fetch. Keep it in NIX_CONFIG only; do not write it to disk,
	# because a cloud snapshot would capture ~/.config/nix/nix.conf.
	if [ -n "${GITHUB_TOKEN:-}" ]; then
		export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}access-tokens = github.com=${GITHUB_TOKEN}"
	fi

	local -a missing=()
	local pkg listing
	listing="$(profile_listing)"
	for pkg in "${PACKAGES[@]}"; do
		# Flake attribute is `legacyPackages.<system>.<pkg>`.
		if profile_has "$listing" ".${pkg}"; then
			continue
		fi
		missing+=("${installable}#${pkg}")
	done

	if [ "${#missing[@]}" -eq 0 ]; then
		log "CI tools already present in the Nix profile"
		return 0
	fi

	nix profile add --extra-experimental-features 'nix-command flakes' "${missing[@]}"
}

link_bins() {
	local dest="/usr/local/bin"
	local bin name
	sudo mkdir -p "$dest"
	if [ -d "$HOME/.nix-profile/bin" ]; then
		for bin in "$HOME/.nix-profile/bin/"*; do
			[ -e "$bin" ] || continue
			name="$(basename "$bin")"
			sudo ln -sfn "$bin" "${dest}/${name}"
		done
	fi
	if [ -x /nix/var/nix/profiles/default/bin/nix ]; then
		sudo ln -sfn /nix/var/nix/profiles/default/bin/nix "${dest}/nix"
	fi

	# Login shells (install, start, `bash -lc`) do not read ~/.bashrc.
	local profile_snippet="/etc/profile.d/99-dotfiles-nix-path.sh"
	sudo tee "$profile_snippet" >/dev/null <<'EOF'
# Added by .cursor/cloud-agent-install.sh so login shells find Nix and the
# CI tools. Symlinks in /usr/local/bin cover non-login shells.
case ":${PATH}:" in
*":${HOME}/.nix-profile/bin:"*) ;;
*)
	if [ -d "${HOME}/.nix-profile/bin" ]; then
		export PATH="${HOME}/.nix-profile/bin:${PATH}"
	fi
	;;
esac
case ":${PATH}:" in
*":/nix/var/nix/profiles/default/bin:"*) ;;
*)
	if [ -d /nix/var/nix/profiles/default/bin ]; then
		export PATH="/nix/var/nix/profiles/default/bin:${PATH}"
	fi
	;;
esac
EOF
	sudo chmod 644 "$profile_snippet"
}

verify_tools() {
	local tool
	# Non-login PATH: only the default directories, so symlinks must work.
	local plain_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
	for tool in nix shellcheck dprint nu shfmt nixfmt kdlfmt nufmt taplo gitleaks deno; do
		if ! PATH="$plain_path" command -v "$tool" >/dev/null 2>&1; then
			printf 'missing %s on the default PATH\n' "$tool" >&2
			exit 1
		fi
	done
	log "nix $(PATH="$plain_path" nix --version)"
	log "deno $(PATH="$plain_path" deno --version | head -n 1)"
	log "nu $(PATH="$plain_path" nu --version | head -n 1)"
}

# `nix flake check` reads this gitignored file from ~/.config/nix. The copy
# next to the flake is invisible to Nix because it is not in the git tree.
ensure_machine_nix() {
	local dest="$HOME/.config/nix/machine.nix"
	if [ -f "$dest" ]; then
		log "machine.nix already present at $dest"
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	log "Generating machine.nix for this host"
	nu "$REPO_ROOT/Configs/scripts/.local/bin/generate-machine-config" --output "$dest"
}

install_apt_packages
install_nix
install_tools
link_bins
verify_tools
ensure_machine_nix
log "Cloud agent toolchain is ready"
