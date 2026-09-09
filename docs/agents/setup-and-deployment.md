# Setup And Deployment

For the human-oriented onboarding path, see [../getting-started.md](../getting-started.md).

## Automated Setup (Preferred)

```bash
# Remote install (safe default core preset)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Remote install (full workstation setup)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --preset workstation

# Read-only preflight check
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --doctor

# Local clone and setup
git clone https://github.com/ifiokjr/dotfiles.git ~/path/to/dotfiles
cd ~/path/to/dotfiles
./setup
```

## Setup Script Options

- `--cwd PATH`: clone to custom path.
- `--preset NAME`: choose `core`, `dev`, `workstation`, or `ci`.
- `--groups GROUPS`: deploy specific comma-separated groups.
- `--skip-nix`: skip Nix install.
- `--lite`: enable CLI-focused install and skip GUI-heavy applications.
- `--desktop`: mark `machine.nix` `isDesktop = true` (podman/launchd desktop bits).
- `--always-on`: mark `machine.nix` `alwaysOn = true` (never sleeps, screensaver lock).
- `--doctor`: run preflight checks without changing the machine.
- `--validate-metadata`: validate `Configs/*.group.toml` files and exit.
- `--dry-run`: print the setup execution plan and exit.
- `--list-groups`: list available configuration groups.
- `--explain-group NAME`: show details for one configuration group.
- `--resume`: resume from the last failed phase or group.
- `--from TARGET`: resume from a specific phase or deployment group.
- `--only GROUPS`: retry only the specified comma-separated groups.
- `--no-confirm`: non-interactive mode.
- `--help`: show help.

## Presets

- `core`: shell, editor, and foundational CLI tooling; now the default setup path.
- `dev`: `core` plus development tools and managed CLIs.
- `workstation`: `dev` plus GUI-heavy personal-machine configuration.
- `ci`: minimal non-interactive setup for CI and containers.

The setup script prints a human-readable execution plan before deployment so users can see the target repo path, Nix/bootstrap expectations, group order, and hook-bearing groups ahead of time. It also supports discovery commands such as `./setup --list-groups` and `./setup --explain-group pnpm`. After a successful run, setup prints a short verification summary covering key tools, representative symlinks, and the Tuckr path, and writes `~/.local/state/dotfiles/setup-report.json`. If a run fails, setup records the last phase in `~/.local/state/dotfiles/setup-phase` so `--resume`, `--from`, and `--only` can be used intentionally.

## Manual Setup

```bash
./setup-tuckr-symlink.sh
# Then deploy groups using tuckr commands from the architecture/deployment guidance.
```

## Common Commands

```bash
tuckr add <group>
tuckr add --force <group>
tuckr rm <group>
tuckr set <group>
tuckr status

dot rebuild
dot rebuild --lite
dot rebuild --no-lite
./setup --validate-metadata
tuckr set nix
```

## Live Update Model

Configs are symlinked, so editing either the repo file or the deployed path updates the same file immediately.

## Remote Rebuilds

Headless fleet machines can opt in to passwordless sudo with `unattendedSudo = true` in `machine.nix` (a per-machine flag, intentionally independent of `lite`). With the flag set, machines can be rebuilt unattended over the tailnet without a TTY for the sudo password:

```bash
ssh <host> 'dot rebuild --latest'
```

- **macOS**: the flag appends a `NOPASSWD` rule for the primary user to `/etc/sudoers.d/10-nix-darwin-extra-config` (`security.sudo.extraConfig` in `Configs/nix/.config/nix/darwin.nix`).
- **Linux**: the home-manager activation installs and keeps `/etc/sudoers.d/10-home-manager-unattended` in sync (validated with `visudo` before install).
- **Bootstrap**: the rebuild that first enables the flag still needs one interactive authentication. Run it with a TTY (`ssh -t <host> 'dot rebuild --unattended-sudo'`) or at the machine; every later rebuild is fully unattended.
- **Security**: the flag lets any code running as the primary user escalate to root without a password. Only enable it on machines you administer unattended; leave interactive workstations off (default). Toggle with `dot machine set-unattended-sudo on|off` or `dot rebuild --unattended-sudo` / `--no-unattended-sudo`.
