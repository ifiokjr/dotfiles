#!/usr/bin/env bash
set -euo pipefail

# Rebuild system configuration after nix config changes.
# This hook inlines the rebuild logic in bash so it does not depend on nushell
# (which may have been removed from the nix profile moments before).
echo "==> Rebuilding system configuration..."

# Source nix environment if available (needed when hook runs in a fresh shell,
# e.g. during setup where the parent process has nix in PATH but child doesn't)
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
	# shellcheck disable=SC1091
	. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Also add user nix profile to PATH (for nix profile-installed tools like nu)
if [ -d "$HOME/.nix-profile/bin" ]; then
	export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# Add ~/.local/bin to PATH (for rebuild, generate-machine-config, etc.
# deployed by the scripts group which is deployed before nix)
if [ -d "$HOME/.local/bin" ]; then
	export PATH="$HOME/.local/bin:$PATH"
fi

# setup may run before the user's shell has loaded Nix. Put known Nix/Darwin
# profile locations ahead of the inherited PATH so nh can find nix during
# first-time bootstrap and partially-activated states.
PROFILE_USER="${USER:-$(whoami)}"
for p in \
	"/nix/var/nix/profiles/default/bin" \
	"/run/current-system/sw/bin" \
	"/etc/profiles/per-user/${PROFILE_USER}/bin" \
	"$HOME/.nix-profile/bin" \
	"$HOME/.local/state/nix/profiles/home-manager/home-path/bin" \
	"$HOME/.local/bin" \
	"/usr/local/bin" \
	"/usr/bin" \
	"/bin" \
	"/usr/sbin" \
	"/sbin"; do
	if [ -d "$p" ]; then
		export PATH="$p:$PATH"
	fi
done

if ! command -v nix >/dev/null 2>&1; then
	echo "ERROR: nix not found after bootstrapping PATH" >&2
	echo "Expected /nix/var/nix/profiles/default/bin/nix or /run/current-system/sw/bin/nix" >&2
	exit 1
fi

SUDO_KEEPALIVE_PID=""
SUDO_SESSION_READY=false

ensure_darwin_sudo_session() {
	if [[ "$OSTYPE" != "darwin"* ]]; then
		return
	fi
	if [ "$SUDO_SESSION_READY" = true ]; then
		return
	fi

	echo "==> Preparing sudo session for nix-darwin..."
	sudo -v

	local sudoers_extra="/etc/sudoers.d/10-nix-darwin-extra-config"
	if [ ! -f "$sudoers_extra" ] || ! sudo grep -q "timestamp_type=global" "$sudoers_extra" 2>/dev/null; then
		echo "==> Bootstrapping global sudo timestamps..."
		printf '%s\n' 'Defaults timestamp_type=global' 'Defaults timestamp_timeout=15' | sudo tee -a "$sudoers_extra" >/dev/null
		sudo chmod 0440 "$sudoers_extra"
		echo "Added timestamp_type=global and timestamp_timeout=15 to sudoers"
	fi

	# Refresh the sudo ticket after any sudoers changes so Homebrew subprocesses
	# spawned from nix-darwin can reuse the cached credentials across process trees.
	sudo -v
	SUDO_SESSION_READY=true
}

start_darwin_sudo_keepalive() {
	if [[ "$OSTYPE" != "darwin"* ]]; then
		return
	fi

	ensure_darwin_sudo_session

	if [ -n "$SUDO_KEEPALIVE_PID" ] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
		return
	fi

	(
		while true; do
			sudo -n true >/dev/null 2>&1 || exit
			sleep 30
		done
	) &
	SUDO_KEEPALIVE_PID=$!
	echo "==> Started sudo keepalive (pid $SUDO_KEEPALIVE_PID)"
}

# shellcheck disable=SC2329
# Invoked indirectly via trap.
stop_darwin_sudo_keepalive() {
	if [ -n "$SUDO_KEEPALIVE_PID" ] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
		kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
		wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
		echo "==> Stopped sudo keepalive"
	fi
}

trap stop_darwin_sudo_keepalive EXIT

backup_for_nix_darwin() {
	local f="$1"
	local target
	if [ -f "$f" ] && [ ! -L "$f" ]; then
		target="${f}.before-nix-darwin"
		if sudo test -e "$target"; then
			target="${target}.$(date +%Y%m%d%H%M%S)"
		fi
		echo "Renaming $f → $target"
		sudo mv "$f" "$target"
	fi
}

# nix-darwin activation refuses to overwrite /etc files it doesn't manage.
# Rename any conflicting files so the first nh darwin switch succeeds.
# This includes sudoers.d files we bootstrap for global sudo timestamps —
# nix-darwin manages that file via security.sudo.extraConfig and will
# recreate it during activation.
if [[ "$OSTYPE" == "darwin"* ]]; then
	ensure_darwin_sudo_session
	start_darwin_sudo_keepalive
	for f in /etc/zshenv /etc/zshrc /etc/bashrc /etc/zprofile /etc/sudoers.d/10-nix-darwin-extra-config; do
		backup_for_nix_darwin "$f"
	done
fi

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
# Two directories matter:
#   NIX_LINK_DIR  = ~/.config/nix (where machine.nix and nix.conf live)
#   NIX_FLAKE_DIR = resolved repo path (for --flake, so nix finds git root)
#
# ~/.config/nix may be a real directory (created for nix.conf before tuckr)
# with tuckr-created file-level symlinks inside. We follow the flake.nix
# symlink to find the actual git repo directory for flake evaluation.
NIX_LINK_DIR="$HOME/.config/nix"

resolve_flake_dir() {
	# Case 1: flake.nix is a symlink (tuckr file-level symlink)
	if [ -L "$NIX_LINK_DIR/flake.nix" ]; then
		local target target_dir
		target="$(readlink "$NIX_LINK_DIR/flake.nix")"
		target_dir="$(dirname "$target")"
		if [[ "$target_dir" = /* ]]; then
			(cd "$target_dir" && pwd -P)
		else
			(cd "$NIX_LINK_DIR/$target_dir" && pwd -P)
		fi
		return
	fi

	# Case 2: ~/.config/nix itself is a symlink (tuckr dir-level symlink)
	if [ -L "$NIX_LINK_DIR" ]; then
		(cd "$NIX_LINK_DIR" && pwd -P)
		return
	fi

	# Case 3: real directory, no symlinks — use as-is
	echo "$NIX_LINK_DIR"
}

NIX_FLAKE_DIR="$(resolve_flake_dir)"
echo "Nix link directory: $NIX_LINK_DIR"
echo "Nix flake directory: $NIX_FLAKE_DIR"

MACHINE_NIX="$NIX_LINK_DIR/machine.nix"
SETUP_LITE_MODE="${SETUP_LITE:-false}"

# ---------------------------------------------------------------------------
# Configure GitHub access token (avoid API rate limits in CI)
# ---------------------------------------------------------------------------
USER_NIX_CONF="$NIX_LINK_DIR/nix.conf"
if [ -n "${GITHUB_TOKEN:-}" ]; then
	mkdir -p "$NIX_LINK_DIR"
	if [ ! -f "$USER_NIX_CONF" ] || ! grep -q "access-tokens" "$USER_NIX_CONF"; then
		echo "access-tokens = github.com=$GITHUB_TOKEN" >>"$USER_NIX_CONF"
		echo "Configured GitHub access token in user nix.conf"
	fi
	# Also configure in system nix.conf so sudo operations (nh darwin switch) can
	# access the token. sudo changes the user context, so the user nix.conf isn't read.
	if [ -d /etc/nix ] && ! sudo grep -q "access-tokens" /etc/nix/nix.conf 2>/dev/null; then
		echo "access-tokens = github.com=$GITHUB_TOKEN" | sudo tee -a /etc/nix/nix.conf >/dev/null
		echo "Configured GitHub access token in system nix.conf"
	fi
fi

# ---------------------------------------------------------------------------
# Generate machine.nix if missing
# ---------------------------------------------------------------------------
if [ ! -f "$MACHINE_NIX" ]; then
	echo "machine.nix not found at: $MACHINE_NIX"
	echo "Auto-generating machine configuration..."

	USERNAME="${USER:-$(whoami)}"

	# Detect architecture (normalize arm64 → aarch64)
	RAW_ARCH="$(uname -m)"
	case "$RAW_ARCH" in
	arm64 | aarch64) ARCH="aarch64" ;;
	x86_64) ARCH="x86_64" ;;
	*) echo "Unsupported architecture: $RAW_ARCH" && exit 1 ;;
	esac

	# Detect OS
	RAW_OS="$(uname -s)"
	case "$RAW_OS" in
	Darwin) NIX_OS="darwin" ;;
	*) NIX_OS="linux" ;;
	esac

	SYSTEM="${ARCH}-${NIX_OS}"

	# Detect hostname
	if [ "$NIX_OS" = "darwin" ]; then
		HOSTNAME="$(scutil --get ComputerName 2>/dev/null || hostname -s)"
	else
		HOSTNAME="$(hostname -s 2>/dev/null || hostname)"
	fi

	mkdir -p "$NIX_LINK_DIR"
	LITE_MACHINE_BLOCK=""
	if [ "$SETUP_LITE_MODE" = "true" ]; then
		LITE_MACHINE_BLOCK='
  # Lite profile (CLI-focused, skips GUI-heavy applications)
  lite = true;'
	fi
	cat >"$MACHINE_NIX" <<-ENDMACHINE
		# Machine-specific configuration
		# Auto-generated by nix post-hook
		# This file is gitignored and will not be committed
		{
		  # Your username on this machine
		  username = "$USERNAME";

		  # System architecture
		  system = "$SYSTEM";

		  # Machine hostname
		  hostname = "$HOSTNAME";
		${LITE_MACHINE_BLOCK}
		}
	ENDMACHINE

	echo "Created machine.nix  Username=$USERNAME  System=$SYSTEM  Hostname=$HOSTNAME  Lite=$SETUP_LITE_MODE"
fi

# If setup requested lite mode, ensure machine.nix explicitly enables it.
if [ "$SETUP_LITE_MODE" = "true" ]; then
	TMP_MACHINE_NIX="$(mktemp)"

	if grep -Eq '^[[:space:]]*lite[[:space:]]*=' "$MACHINE_NIX"; then
		sed -E 's/^[[:space:]]*lite[[:space:]]*=.*/  lite = true;/' "$MACHINE_NIX" >"$TMP_MACHINE_NIX"
		mv "$TMP_MACHINE_NIX" "$MACHINE_NIX"
		echo "Updated machine.nix: set lite = true"
	else
		awk '
			/^[[:space:]]*}[[:space:]]*$/ && !inserted {
				print ""
				print "  # Lite profile (CLI-focused, skips GUI-heavy applications)"
				print "  lite = true;"
				inserted = 1
			}
			{ print }
		' "$MACHINE_NIX" >"$TMP_MACHINE_NIX"
		mv "$TMP_MACHINE_NIX" "$MACHINE_NIX"
		echo "Updated machine.nix: added lite = true"
	fi
fi

# ---------------------------------------------------------------------------
# Parse machine.nix — extract username and system via grep/sed
# ---------------------------------------------------------------------------
CFG_USERNAME="$(grep 'username = ' "$MACHINE_NIX" | sed 's/.*"\([^"]*\)".*/\1/')"
CFG_SYSTEM="$(grep 'system = ' "$MACHINE_NIX" | sed 's/.*"\([^"]*\)".*/\1/')"
CFG_LITE="false"
if grep -Eq '^[[:space:]]*lite[[:space:]]*=[[:space:]]*true;' "$MACHINE_NIX"; then
	CFG_LITE="true"
fi

if [ -z "$CFG_USERNAME" ] || [ -z "$CFG_SYSTEM" ]; then
	echo "ERROR: Failed to read username or system from machine.nix"
	exit 1
fi

echo "Configuration:  Username=$CFG_USERNAME  System=$CFG_SYSTEM  Lite=$CFG_LITE"

# ---------------------------------------------------------------------------
# Detect root-only nix (Docker/containers without systemd)
# ---------------------------------------------------------------------------
ROOT_ONLY_NIX=false
if [ ! -d "/run/systemd/system" ] && [ ! -S "/nix/var/nix/daemon-socket/socket" ] && [ "$(id -u)" != "0" ]; then
	ROOT_ONLY_NIX=true
fi

SUDO_PREFIX=""
if [ "$ROOT_ONLY_NIX" = true ]; then
	SUDO_PREFIX="sudo"
fi

# ---------------------------------------------------------------------------
# Rebuild
# ---------------------------------------------------------------------------
REBUILD_EXIT=0

if [[ "$OSTYPE" == "darwin"* ]]; then
	ensure_darwin_sudo_session
	start_darwin_sudo_keepalive

	# Back up /etc/shells before nix-darwin takes ownership.
	# If a previous backup exists from an earlier failed setup, use a timestamped
	# backup name so the current regular file still gets moved out of the way.
	# Once nix-darwin owns /etc/shells it is a symlink, which this intentionally skips.
	if [ -f /etc/shells ] && [ ! -L /etc/shells ]; then
		target="/etc/shells.before-nix-darwin"
		if sudo test -e "$target"; then
			target="${target}.$(date +%Y%m%d%H%M%S)"
		fi
		echo "==> Backing up /etc/shells to $target"
		sudo mv /etc/shells "$target"
	fi

	# Build nh darwin command (with nix run fallback for first-time setup)
	if command -v nh &>/dev/null; then
		DARWIN_CMD="nh darwin switch '${NIX_FLAKE_DIR}' -H default --impure --verbose"
	else
		echo "nh not found, using nix run nixpkgs#nh for first-time setup..."
		DARWIN_CMD="nix run nixpkgs#nh -- darwin switch '${NIX_FLAKE_DIR}' -H default --impure --verbose"
	fi

	REBUILD_CMD="ulimit -n 10240 && NIX_USER_CONFIG_DIR='${NIX_LINK_DIR}' ${DARWIN_CMD}"
	# Time the rebuild so we can report how long it took.
	REBUILD_START=$(date +%s)
	echo "==> Starting nix-darwin rebuild (may prompt for sudo)..."
	bash -c "$REBUILD_CMD" || REBUILD_EXIT=$?
	REBUILD_ELAPSED=$(($(date +%s) - REBUILD_START))
	if [ "$REBUILD_EXIT" -ne 0 ]; then
		echo "==> nix-darwin rebuild FAILED after ${REBUILD_ELAPSED}s (exit $REBUILD_EXIT), continuing with post-rebuild steps..."
	else
		echo "==> nix-darwin rebuild SUCCEEDED after ${REBUILD_ELAPSED}s! (darwin + home-manager)"
	fi
else
	# Linux: build and activate the standalone home-manager configuration directly.
	# This avoids first-time bootstrap failures from nh's configuration lookup while
	# still using the same activation package generated by the flake.
	HM_CONFIGURATION="${CFG_USERNAME}@${CFG_SYSTEM}"
	HM_PROFILE_LINK="${HOME}/.local/state/nix/profiles/home-manager"
	HM_CMD="nix build '${NIX_FLAKE_DIR}#homeConfigurations.${HM_CONFIGURATION}.activationPackage' --impure --out-link '${HM_PROFILE_LINK}' && '${HM_PROFILE_LINK}/activate'"

	REBUILD_CMD="${SUDO_PREFIX} USER=${CFG_USERNAME} HOME=${HOME} NIX_USER_CONFIG_DIR='${NIX_LINK_DIR}' ${HM_CMD}"
	# Time the rebuild so we can report how long it took.
	REBUILD_START=$(date +%s)
	echo "==> Starting home-manager activation..."
	bash -c "$REBUILD_CMD" || REBUILD_EXIT=$?
	REBUILD_ELAPSED=$(($(date +%s) - REBUILD_START))
	if [ "$REBUILD_EXIT" -ne 0 ]; then
		echo "==> home-manager activation FAILED after ${REBUILD_ELAPSED}s (exit $REBUILD_EXIT), continuing with post-rebuild steps..."
	else
		echo "==> home-manager activation SUCCEEDED after ${REBUILD_ELAPSED}s!"
	fi
fi

# ---------------------------------------------------------------------------
# Clean up flake.lock generated during nix evaluation.
# This file is gitignored and regenerated every rebuild. If left in the source
# directory, tuckr status reports nix as "Not Symlinked" because the file
# exists in the source without a corresponding symlink in ~/.config/nix/.
# ---------------------------------------------------------------------------
echo "==> Cleaning up flake.lock..."
rm -f "$NIX_FLAKE_DIR/flake.lock"

# ---------------------------------------------------------------------------
# Post-rebuild: add profile paths so newly installed tools are found
# ---------------------------------------------------------------------------
echo "==> Post-rebuild: adding profile paths to PATH..."
for p in \
	"/etc/profiles/per-user/${USER:-$(whoami)}/bin" \
	"$HOME/.local/state/nix/profiles/home-manager/home-path/bin" \
	"/run/current-system/sw/bin"; do
	if [ -d "$p" ]; then
		export PATH="$p:$PATH"
	fi
done

# ---------------------------------------------------------------------------
# Explicitly reconcile managed pnpm globals after a successful rebuild so
# global CLI tools are installed even when activation hooks were best-effort.
# ---------------------------------------------------------------------------
echo "==> Post-rebuild: syncing pnpm global packages..."
if [ "$REBUILD_EXIT" -eq 0 ]; then
	PNPM_SYNC_SCRIPT="$HOME/.local/bin/pnpm:global:sync"
	if [ ! -x "$PNPM_SYNC_SCRIPT" ]; then
		THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
		FALLBACK_SYNC_SCRIPT="$(cd "$THIS_DIR/../.." && pwd -P)/Configs/scripts/.local/bin/pnpm:global:sync"
		if [ -x "$FALLBACK_SYNC_SCRIPT" ]; then
			PNPM_SYNC_SCRIPT="$FALLBACK_SYNC_SCRIPT"
		fi
	fi

	if [ -x "$PNPM_SYNC_SCRIPT" ]; then
		SYNC_ARGS=()
		if [ "$CFG_LITE" = "true" ]; then
			echo "Lite mode enabled; running pnpm global sync in best-effort mode"
			SYNC_ARGS+=(--no-fail)
		fi

		echo "==> Syncing managed pnpm global packages..."
		if ! "$PNPM_SYNC_SCRIPT" "${SYNC_ARGS[@]}"; then
			echo "==> ERROR: managed pnpm global package sync failed"
			REBUILD_EXIT=1
		fi
	else
		echo "==> ERROR: pnpm:global:sync not found after rebuild"
		REBUILD_EXIT=1
	fi
fi

# After rebuild, make home-manager packages available to subsequent CI steps.
if [ -n "${GITHUB_ACTIONS:-}" ] && [ -n "${GITHUB_PATH:-}" ]; then
	# Add all profile paths that may contain tools
	for p in \
		"$HOME/.local/state/nix/profiles/home-manager/home-path/bin" \
		"/etc/profiles/per-user/${USER:-$(whoami)}/bin" \
		"/run/current-system/sw/bin"; do
		if [ -d "$p" ]; then
			echo "$p" >>"$GITHUB_PATH"
			echo "Added to GITHUB_PATH: $p"
		fi
	done

	# Also source hm-session-vars.sh if available (sets HOME_MANAGER_VARS, etc.)
	# Temporarily disable nounset — the script references variables that may be unset.
	HM_VARS="$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
	if [ -f "$HM_VARS" ]; then
		set +u
		# shellcheck disable=SC1090
		. "$HM_VARS"
		set -u
	fi
fi

# Propagate rebuild failure so callers know the rebuild didn't fully succeed.
exit "$REBUILD_EXIT"
