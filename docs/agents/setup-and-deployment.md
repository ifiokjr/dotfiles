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
- `--doctor`: run preflight checks without changing the machine.
- `--validate-metadata`: validate `Configs/*.group.toml` files and exit.
- `--dry-run`: print the setup execution plan and exit.
- `--list-groups`: list available configuration groups.
- `--explain-group NAME`: show details for one configuration group.
- `--no-confirm`: non-interactive mode.
- `--help`: show help.

## Presets

- `core`: shell, editor, and foundational CLI tooling; now the default setup path.
- `dev`: `core` plus development tools and managed CLIs.
- `workstation`: `dev` plus GUI-heavy personal-machine configuration.
- `ci`: minimal non-interactive setup for CI and containers.

The setup script prints a human-readable execution plan before deployment so users can see the target repo path, Nix/bootstrap expectations, group order, and hook-bearing groups ahead of time. It also supports discovery commands such as `./setup --list-groups` and `./setup --explain-group pnpm`. After a successful run, setup prints a short verification summary covering key tools, representative symlinks, and the Tuckr path, and writes `~/.local/state/dotfiles/setup-report.json`.

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

rebuild
rebuild --lite
rebuild --no-lite
./setup --validate-metadata
tuckr set nix
```

## Live Update Model

Configs are symlinked, so editing either the repo file or the deployed path updates the same file immediately.
