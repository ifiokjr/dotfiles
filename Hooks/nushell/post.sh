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

# Generate vendor autoload scripts using nushell to resolve the correct data dir
# (on macOS without XDG_DATA_HOME, this is ~/Library/Application Support/nushell/)
if [ -x "$NU_PATH" ]; then
	# shellcheck disable=SC2016
	VENDOR_AUTOLOAD_DIR=$("$NU_PATH" -c '$nu.data-dir | path join "vendor/autoload"')
	mkdir -p "$VENDOR_AUTOLOAD_DIR"

	# Generate starship init (per https://starship.rs/guide/)
	if command -v starship &>/dev/null; then
		# shellcheck disable=SC2016
		"$NU_PATH" -c 'starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")'
		echo -e "${GREEN}✓${NC} Generated starship.nu"
	else
		echo -e "${YELLOW}!${NC} starship not found, skipping starship.nu"
	fi

	# Generate carapace completions
	if command -v carapace &>/dev/null; then
		carapace _carapace nushell >"$VENDOR_AUTOLOAD_DIR/carapace.nu"
		echo -e "${GREEN}✓${NC} Generated carapace.nu"
	else
		echo -e "${YELLOW}!${NC} carapace not found, skipping carapace.nu"
	fi

	# Generate atuin init
	if command -v atuin &>/dev/null; then
		ATUIN_AUTOLOAD_FILE="$VENDOR_AUTOLOAD_DIR/atuin.nu"
		atuin init nu >"$ATUIN_AUTOLOAD_FILE"
		# Older Atuin-generated Nushell init scripts used `job spawn -t <name>`,
		# but Nushell 0.112+ removed `-t`. Normalize the generated script so the
		# integration works across mixed Atuin/Nushell upgrade states.
		sed -i '' -E 's/job spawn -t [^ ]+ \{/job spawn {/' "$ATUIN_AUTOLOAD_FILE" 2>/dev/null ||
			sed -i -E 's/job spawn -t [^ ]+ \{/job spawn {/' "$ATUIN_AUTOLOAD_FILE" 2>/dev/null || true
		echo -e "${GREEN}✓${NC} Generated atuin.nu"
	else
		echo -e "${YELLOW}!${NC} atuin not found, skipping atuin.nu"
	fi

	# Generate mise activation (patch add-hook for Nushell compatibility: update optional true -> each { merge } )
	if command -v mise &>/dev/null; then
		mise activate nu >"$VENDOR_AUTOLOAD_DIR/mise.nu"
		# Fix add-hook: "update optional true" pipeline is incompatible in recent Nushell; use each/merge instead
		# (SC2016: $r must stay literal in sed replacement - it is the Nushell variable name in the generated script)
		# shellcheck disable=SC2016
		sed -i '' 's#| update optional true | into cell-path#| each { |r| $r | merge { optional: true } } | into cell-path#' "$VENDOR_AUTOLOAD_DIR/mise.nu" 2>/dev/null ||
			sed -i 's#| update optional true | into cell-path#| each { |r| $r | merge { optional: true } } | into cell-path#' "$VENDOR_AUTOLOAD_DIR/mise.nu" 2>/dev/null || true
		# Fix deprecated --ignore-errors flag (renamed to --optional in nushell 0.106.0)
		sed -i '' 's#--ignore-errors#--optional#g' "$VENDOR_AUTOLOAD_DIR/mise.nu" 2>/dev/null ||
			sed -i 's#--ignore-errors#--optional#g' "$VENDOR_AUTOLOAD_DIR/mise.nu" 2>/dev/null || true
		echo -e "${GREEN}✓${NC} Generated mise.nu"
	else
		echo -e "${YELLOW}!${NC} mise not found, skipping mise.nu"
	fi

	# Generate zoxide init
	if command -v zoxide &>/dev/null; then
		# shellcheck disable=SC2016
		"$NU_PATH" -c 'zoxide init nushell | save -f ($nu.data-dir | path join "vendor/autoload/zoxide.nu")'
		echo -e "${GREEN}✓${NC} Generated zoxide.nu"
	else
		echo -e "${YELLOW}!${NC} zoxide not found, skipping zoxide.nu"
	fi
else
	echo -e "${YELLOW}!${NC} $NU_PATH not found, skipping vendor autoload generation"
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

# Setup .env.dotfiles from example if it doesn't exist
ENV_FILE="$HOME/.env.dotfiles"
EXAMPLE_FILE="Configs/nushell/.env.dotfiles.example"

if [ ! -f "$ENV_FILE" ]; then
	if [ -f "$EXAMPLE_FILE" ]; then
		cp "$EXAMPLE_FILE" "$ENV_FILE"
		echo -e "${GREEN}✓${NC} Created $ENV_FILE from example"
		echo -e "${YELLOW}!${NC} Please edit $ENV_FILE and add your API keys/tokens"
	else
		echo -e "${YELLOW}!${NC} Warning: Could not find $EXAMPLE_FILE"
	fi
else
	echo -e "${BLUE}→${NC} $ENV_FILE already exists (not overwriting)"
fi

echo -e "${BLUE}→${NC} Open a new terminal window to use nushell"
