#!/usr/bin/env bash
# Docker integration test: generates machine config, runs rebuild, then verifies.
#
# This script runs inside the Docker container after
# `SETUP_ALLOW_NIX_HOOK_FAILURE=true ./setup --no-confirm`
# has already executed during the image build step.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC} $1"; }
fail() {
	echo -e "${RED}FAIL${NC} $1"
	exit 1
}
step() { echo -e "\n${BOLD}${CYAN}==> $1${NC}"; }

# Source nix so tools are available in this shell
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
	# shellcheck disable=SC1091
	. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Add user nix profile to PATH (for nix profile-installed and home-manager tools)
if [ -d "$HOME/.nix-profile/bin" ]; then
	export PATH="$HOME/.nix-profile/bin:$PATH"
fi

# Start nix daemon in background (Docker has no systemd to manage it).
# Without the daemon, nix commands require sudo which breaks home-manager
# activation (it checks USER matches the configured username).
if [ ! -S /nix/var/nix/daemon-socket/socket ]; then
	step "Starting nix daemon"
	sudo /nix/var/nix/profiles/default/bin/nix-daemon &
	# Wait for the socket to appear
	for _ in $(seq 1 10); do
		[ -S /nix/var/nix/daemon-socket/socket ] && break
		sleep 1
	done
	if [ -S /nix/var/nix/daemon-socket/socket ]; then
		pass "nix daemon started"
	else
		fail "nix daemon failed to start"
	fi
fi

# ----- Step 1: Generate machine.nix -----
step "Generating machine.nix"
nu "$HOME/.local/bin/generate-machine-config" --force
pass "machine.nix generated"

# ----- Step 2: Run rebuild (home-manager switch on Linux) -----
step "Running rebuild"
nu "$HOME/.local/bin/rebuild" --skip-check
pass "rebuild completed"

# ----- Step 3: Run verification tests -----
step "Running verification tests"
nu tests/docker-verify.nu
pass "all verification tests passed"

echo ""
echo -e "${GREEN}${BOLD}All integration tests passed!${NC}"
