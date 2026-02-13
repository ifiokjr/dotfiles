#!/usr/bin/env bash
# Docker integration test: runs setup + rebuild on Linux and verifies the result.
#
# This script is intended to run inside the Docker container defined by the
# repo-root Dockerfile. Nix and nushell are pre-installed in the Docker image
# for caching; the setup script is invoked with --skip-nix.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC} $1"; }
fail() { echo -e "${RED}FAIL${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}${CYAN}==> $1${NC}"; }

# Source nix so it's available in this shell
if [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# ----- Step 1: Run setup -----
step "Running ./setup --skip-nix"
./setup --skip-nix
pass "setup completed"

# ----- Step 2: Generate machine config -----
step "Generating machine.nix"
nu Configs/scripts/.local/bin/generate-machine-config
pass "machine.nix generated"

# ----- Step 3: Run rebuild (home-manager switch on Linux) -----
step "Running rebuild"
nu Configs/scripts/.local/bin/rebuild --skip-check
pass "rebuild completed"

# ----- Step 4: Run verification tests -----
step "Running verification tests"
nu tests/docker-verify.nu
pass "all verification tests passed"

echo ""
echo -e "${GREEN}${BOLD}All integration tests passed!${NC}"
