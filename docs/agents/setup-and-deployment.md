# Setup And Deployment

## Automated Setup (Preferred)

```bash
# Remote install
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Remote install (lite mode)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --lite

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
- `--no-confirm`: non-interactive mode.
- `--help`: show help.

## Presets

- `core`: shell, editor, and foundational CLI tooling.
- `dev`: `core` plus development tools and managed CLIs.
- `workstation`: `dev` plus GUI-heavy personal-machine configuration.
- `ci`: minimal non-interactive setup for CI and containers.

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
