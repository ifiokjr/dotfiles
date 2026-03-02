# Setup And Deployment

## Automated Setup (Preferred)

```bash
# Remote install
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Remote install (lite mode)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --lite

# Local clone and setup
git clone https://github.com/ifiokjr/dotfiles.git ~/path/to/dotfiles
cd ~/path/to/dotfiles
./setup
```

## Setup Script Options

- `--cwd PATH`: clone to custom path.
- `--groups GROUPS`: deploy specific comma-separated groups.
- `--skip-nix`: skip Nix install.
- `--lite`: enable CLI-focused install and skip GUI-heavy applications.
- `--no-confirm`: non-interactive mode.
- `--help`: show help.

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
tuckr set nix
```

## Live Update Model

Configs are symlinked, so editing either the repo file or the deployed path updates the same file immediately.
