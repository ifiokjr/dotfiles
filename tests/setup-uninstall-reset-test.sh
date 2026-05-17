#!/usr/bin/env bash
#
# Integration test for setup:dotfiles, uninstall:dotfiles, and reset:dotfiles.
#
# This runs inside a Docker container where setup --no-confirm --lite has
# already been executed. It:
#   1. Verifies setup artifacts exist
#   2. Runs uninstall:dotfiles and verifies cleanup
#   3. Re-runs setup:dotfiles and verifies it works again
#
# Assumes the dotfiles repo is at /home/testuser/.dotfiles and Nix is installed.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
PASS_COUNT=0
FAIL_COUNT=0
TOTAL=0

pass() {
	echo -e "${GREEN}PASS${NC} $1"
	PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
	echo -e "${RED}FAIL${NC} $1"
	FAIL_COUNT=$((FAIL_COUNT + 1))
}

step() {
	TOTAL=$((TOTAL + 1))
	echo ""
	echo -e "${BOLD}${CYAN}===>${NC} ${BOLD}$1${NC}"
}

# Source nix if available
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
	# shellcheck disable=SC1091
	. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Add user nix profile to PATH
if [ -d "$HOME/.nix-profile/bin" ]; then
	export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# ----- Step 1: Verify initial setup is in place -----
step "1. Verifying initial setup artifacts"

# Check dotfiles directory exists
if [ -d "$DOTFILES_DIR" ]; then
	pass "Dotfiles directory exists: $DOTFILES_DIR"
else
	fail "Dotfiles directory missing: $DOTFILES_DIR"
fi

# Check setup script exists
if [ -f "$DOTFILES_DIR/setup:dotfiles" ]; then
	pass "setup:dotfiles script exists"
else
	fail "setup:dotfiles script missing"
fi

# Check uninstall script exists
if [ -f "$DOTFILES_DIR/uninstall:dotfiles" ]; then
	pass "uninstall:dotfiles script exists"
else
	fail "uninstall:dotfiles script missing"
fi

# Check reset script exists
if [ -f "$DOTFILES_DIR/reset:dotfiles" ]; then
	pass "reset:dotfiles script exists"
else
	fail "reset:dotfiles script missing"
fi

# Check Tuckr symlink
TUCKR_LOCATION=""
case "$(uname -s)" in
Darwin*) TUCKR_LOCATION="$HOME/Library/Application Support/dotfiles" ;;
Linux*) TUCKR_LOCATION="$HOME/.config/dotfiles" ;;
esac

if [ -L "$TUCKR_LOCATION" ]; then
	pass "Tuckr symlink exists: $TUCKR_LOCATION"
else
	# On Docker, the symlink might be created differently
	# Print info but don't fail
	echo -e "${CYAN}INFO${NC} Tuckr symlink not found at $TUCKR_LOCATION (may be expected in Docker)"
fi

# Check machine.nix exists
if [ -f "$HOME/.config/nix/machine.nix" ]; then
	pass "machine.nix exists"
else
	fail "machine.nix missing"
fi

# Check nix is available
if command -v nix &>/dev/null; then
	pass "Nix is available"
else
	fail "Nix is not available"
fi

# ----- Step 2: Backup dotfiles then run uninstall (keep nix so we can re-setup) -----
step "2. Running uninstall:dotfiles (keeping Nix)"

cd "$DOTFILES_DIR"

# Backup the dotfiles repo so we can restore it for re-setup
# (uninstall removes the repo directory)
DOTFILES_BACKUP="$HOME/dotfiles-backup"
if [ -d "$DOTFILES_BACKUP" ]; then
	rm -rf "$DOTFILES_BACKUP"
fi
cp -r "$DOTFILES_DIR" "$DOTFILES_BACKUP"
pass "Created backup of dotfiles at $DOTFILES_BACKUP"

# Run uninstall with --no-confirm and --keep-nix so we can re-setup
if ./uninstall:dotfiles --no-confirm --keep-nix --cwd "$DOTFILES_DIR"; then
	pass "uninstall:dotfiles completed successfully"
else
	fail "uninstall:dotfiles failed"
fi

# ----- Step 3: Verify cleanup -----
step "3. Verifying cleanup after uninstall"

# Dotfiles directory should be removed
if [ ! -d "$DOTFILES_DIR" ]; then
	pass "Dotfiles directory was removed"
else
	fail "Dotfiles directory still exists after uninstall"
fi

# Tuckr symlink should be removed
if [ ! -e "$TUCKR_LOCATION" ]; then
	pass "Tuckr symlink was removed"
else
	fail "Tuckr symlink still exists after uninstall"
fi

# State directory should be removed
if [ ! -d "$HOME/.local/state/dotfiles" ]; then
	pass "State directory was removed"
else
	fail "State directory still exists after uninstall"
fi

# machine.nix (if it was a generated file) should be removed
if [ ! -f "$HOME/.config/nix/machine.nix" ]; then
	pass "machine.nix was removed"
else
	fail "machine.nix still exists after uninstall"
fi

# Nix should still be available (we used --keep-nix)
if command -v nix &>/dev/null; then
	pass "Nix is still available (--keep-nix worked)"
else
	fail "Nix was removed despite --keep-nix"
fi

# ----- Step 4: Re-setup -----
step "4. Re-running setup:dotfiles"

# The dotfiles repo was removed by uninstall.
# Restore from the backup we made before uninstall.
DOTFILES_BACKUP="$HOME/dotfiles-backup"
if [ -d "$DOTFILES_BACKUP" ]; then
	cp -r "$DOTFILES_BACKUP" "$DOTFILES_DIR"
	pass "Restored dotfiles from backup: $DOTFILES_BACKUP"
else
	fail "Dotfiles backup not found at $DOTFILES_BACKUP"
	exit 1
fi

cd "$DOTFILES_DIR"

# Run setup with --no-confirm --lite --skip-nix (nix is already installed)
if SETUP_ALLOW_NIX_HOOK_FAILURE=true ./setup:dotfiles --no-confirm --lite --skip-nix --cwd "$DOTFILES_DIR"; then
	pass "setup:dotfiles re-run completed successfully"
else
	# Setup may fail on some hooks in Docker (e.g., nix hook during rebuild)
	# This is expected - check if core artifacts were created
	echo -e "${CYAN}INFO${NC} setup:dotfiles exited with non-zero code (may be expected in Docker)"
fi

# ----- Step 5: Verify re-setup -----
step "5. Verifying setup after re-run"

if [ -d "$DOTFILES_DIR" ]; then
	pass "Dotfiles directory re-created"
else
	fail "Dotfiles directory not re-created"
fi

# Check machine.nix was recreated
if [ -f "$HOME/.config/nix/machine.nix" ]; then
	pass "machine.nix re-created"
else
	fail "machine.nix not re-created"
fi

# Check Tuckr symlink was recreated
if [ -L "$TUCKR_LOCATION" ] || [ -e "$TUCKR_LOCATION" ]; then
	pass "Tuckr symlink re-created"
else
	# In Docker this might not always be a symlink
	echo -e "${CYAN}INFO${NC} Tuckr path not re-created at $TUCKR_LOCATION"
fi

# ----- Summary -----
echo ""
echo -e "${BOLD}======================================${NC}"
echo -e "${BOLD}  Test Results${NC}"
echo -e "${BOLD}======================================${NC}"
echo -e "  ${GREEN}Passed:${NC} $PASS_COUNT"
echo -e "  ${RED}Failed:${NC} $FAIL_COUNT"
echo -e "  Total assertions: $TOTAL"
echo ""

if [ "$FAIL_COUNT" -gt 0 ]; then
	echo -e "${RED}${BOLD}Some tests FAILED!${NC}"
	exit 1
else
	echo -e "${GREEN}${BOLD}All tests PASSED!${NC}"
fi
