#!/usr/bin/env bash

# post_nushell - Generate tool integration scripts and set default shell

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}✓${NC} Nushell configuration deployed"

# ---------------------------------------------------------------------------
# PATH augmentation — ensure nix-installed tools (starship, carapace, etc.)
# are discoverable even when this hook runs before the user's shell profile.
# ---------------------------------------------------------------------------
for p in "/etc/profiles/per-user/${USER}/bin" "/run/current-system/sw/bin" \
	"$HOME/.nix-profile/bin" "/nix/var/nix/profiles/default/bin"; do
	# shellcheck disable=SC2249
	[ -d "$p" ] && case ":$PATH:" in *":$p:"*) ;; *) export PATH="$p:$PATH" ;; esac
done

# On macOS, nushell defaults to ~/Library/Application Support/nushell/ when
# XDG_CONFIG_HOME is not set. Since nix-darwin's set-environment only runs for
# POSIX shells, XDG_CONFIG_HOME won't be set when nushell is the login shell.
# Create a symlink so nushell finds our config at either location.
if [[ "$OSTYPE" == "darwin"* ]]; then
	MACOS_NU_CONFIG="$HOME/Library/Application Support/nushell"
	XDG_NU_CONFIG="$HOME/.config/nushell"

	if [ -L "$MACOS_NU_CONFIG" ]; then
		echo -e "${BLUE}→${NC} macOS config symlink already exists"
	else
		if [ -d "$MACOS_NU_CONFIG" ]; then
			mv "$MACOS_NU_CONFIG" "$MACOS_NU_CONFIG.bak"
			echo -e "${YELLOW}!${NC} Backed up existing config to $MACOS_NU_CONFIG.bak"
		fi
		ln -sf "$XDG_NU_CONFIG" "$MACOS_NU_CONFIG"
		echo -e "${GREEN}✓${NC} Symlinked $MACOS_NU_CONFIG → $XDG_NU_CONFIG"
	fi
fi

# Locate the nushell binary: nix-darwin puts it at /run/current-system/sw/bin/nu,
# but on Linux (or standalone nix) it may only be on PATH via `which`.
NU_PATH="/run/current-system/sw/bin/nu"
if [ ! -x "$NU_PATH" ]; then
	NU_PATH="$(command -v nu 2>/dev/null || true)"
fi

# Vendor autoload generation lives in a shared script so the same refresh can
# run from `dotfiles rebuild` and `dotfiles reload` — the generated files embed
# tool binary paths, so they must track the currently installed tool set, not
# the set present when the nushell group was last deployed.
REFRESH_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../Configs/scripts/.local/bin/refresh-nu-vendor-autoloads"
if [ -x "$REFRESH_SCRIPT" ]; then
	"$REFRESH_SCRIPT"
else
	echo -e "${YELLOW}!${NC} refresh-nu-vendor-autoloads not found, skipping vendor autoload generation"
fi

# Set nushell as default shell via chsh
if [ -x "$NU_PATH" ]; then
	# Validate that nushell actually works before attempting to change shells
	if ! "$NU_PATH" -c 'echo ok' &>/dev/null; then
		echo -e "${YELLOW}!${NC} Nushell binary exists but fails to run, skipping chsh"
	# Skip chsh in non-interactive / CI contexts (would hang waiting for password)
	elif [ "${NO_CONFIRM:-}" = "true" ] || [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
		echo -e "${BLUE}→${NC} Skipping chsh (non-interactive mode)"
	else
		# Detect current shell: macOS uses dscl (Directory Service), Linux uses /etc/passwd
		if [[ "$OSTYPE" == "darwin"* ]]; then
			CURRENT_SHELL=$(dscl . -read /Users/"$USER" UserShell 2>/dev/null | awk '{print $2}')
		else
			CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7)
		fi

		if [ "$CURRENT_SHELL" != "$NU_PATH" ]; then
			# Ensure nu is in /etc/shells (required by chsh on most systems)
			if ! grep -qx "$NU_PATH" /etc/shells 2>/dev/null; then
				echo -e "${YELLOW}!${NC} Adding $NU_PATH to /etc/shells"
				echo "$NU_PATH" | sudo tee -a /etc/shells >/dev/null
			fi
			echo -e "${BLUE}→${NC} Setting default shell to nushell..."
			if chsh -s "$NU_PATH"; then
				echo -e "${GREEN}✓${NC} Default shell set to $NU_PATH"
			else
				echo -e "${YELLOW}!${NC} chsh failed — you can set it manually: chsh -s $NU_PATH"
			fi
		else
			echo -e "${BLUE}→${NC} Default shell is already nushell"
		fi
	fi
else
	echo -e "${YELLOW}!${NC} Nushell not found, skipping chsh"
fi

echo -e "${BLUE}→${NC} Open a new terminal window to use nushell"
