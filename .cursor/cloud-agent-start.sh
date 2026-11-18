#!/usr/bin/env bash
# Bring up the Nix daemon on every cloud agent boot.
#
# The installer uses `--init none` because this image has no systemd, so
# nothing else starts the daemon. Store paths symlinked into /usr/local/bin
# work without it; `nix flake check` and `nix profile` do not.
#
# Idempotent: exit when the daemon already answers. Otherwise replace this
# process with the daemon so a dead daemon shows up as a failed start script.

set -euo pipefail

nix_bin="/nix/var/nix/profiles/default/bin/nix"
daemon_bin="/nix/var/nix/profiles/default/bin/nix-daemon"
socket="/nix/var/nix/daemon-socket/socket"

if [ ! -x "$daemon_bin" ] || [ ! -x "$nix_bin" ]; then
	printf 'Nix is not installed; .cursor/cloud-agent-install.sh has not completed\n' >&2
	exit 1
fi

if "$nix_bin" store ping >/dev/null 2>&1; then
	printf 'Nix daemon is already running\n'
	exit 0
fi

if [ -S "$socket" ]; then
	sudo rm -f "$socket"
fi

exec sudo "$daemon_bin"
