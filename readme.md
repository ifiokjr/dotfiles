# Dotfiles - Tuckr Managed

This repository uses [Tuckr](https://github.com/RaphGL/Tuckr), a modern dotfile manager that creates symlinks from this repository to your home directory.

## Quick Start

<br />

For the canonical onboarding flow, start with [docs/getting-started.md](docs/getting-started.md). It now includes opinionated starter workflows for common goals such as a core shell/editor setup, a full workstation install, CI mode, and incremental Nix + Nushell adoption.

### Automated Setup (Recommended)

<br />

Set up your environment with one command:

```bash
# Remote installation (safe default: core preset)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Full workstation install
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --preset workstation

# Run a read-only preflight check first
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --doctor

# Or clone anywhere you like, then run locally
git clone https://github.com/ifiokjr/dotfiles.git ~/path/to/dotfiles
cd ~/path/to/dotfiles
./setup
```

The setup script handles everything: Nix installation, repository cloning, Tuckr configuration, and automatic deployment of all configuration groups.

If you are setting up a new machine or want the human-oriented walkthrough first, use the canonical guide: [docs/getting-started.md](docs/getting-started.md).

**Setup Script Options:**

- `--preset <name>` - Choose `core`, `dev`, `workstation`, or `ci`
- `--groups <groups>` - Deploy specific groups (comma-separated; overrides preset selection)
- `--cwd <path>` - Clone to custom location (default: `~/Developer/.dotfiles`)
- `--skip-nix` - Skip Nix installation
- `--lite` - Enable CLI-focused install and skip GUI-heavy applications
- `--doctor` - Run preflight checks without changing the machine
- `--validate-metadata` - Validate `Configs/*.group.toml` files and exit
- `--dry-run` - Print the setup execution plan and exit
- `--list-groups` - List available configuration groups
- `--explain-group <name>` - Show details for one configuration group
- `--resume` - Resume from the last failed phase or group
- `--from <target>` - Resume from a specific phase or deployment group
- `--only <groups>` - Retry only the specified comma-separated groups
- `--no-confirm` - Run headlessly without interactive prompts
- `--help` - Show help

### Presets

<br />

- `core` - shell, editor, and foundational CLI tooling; this is now the default setup path
- `dev` - `core` plus development tools and managed CLIs
- `workstation` - `dev` plus GUI-heavy personal-machine configuration
- `ci` - minimal non-interactive setup for CI and containers

Examples:

```bash
./setup --preset core
./setup --preset dev
./setup --preset workstation
./setup --preset ci --no-confirm
./setup --dry-run
./setup --list-groups
./setup --explain-group pnpm
./setup --resume
./setup --from nix
./setup --only pnpm,nushell
```

The setup script now prints an execution plan before meaningful deployment work begins so you can see the platform, repository action, bootstrap tools, groups, and hook-bearing groups ahead of time. After a successful run, it also prints a short verification summary for key tools, symlinks, and the Tuckr link state, and writes a machine-readable report to `~/.local/state/dotfiles/setup-report.json`. On failure, it records the last phase so `./setup --resume` and targeted retries are easier to use.

### Manual Tuckr Commands

<br />

```bash
# Add a group (deploy dotfiles)
tuckr add <group>

# Add with force (overwrite existing files)
tuckr add --force <group>

# Remove a group (remove symlinks)
tuckr rm <group>

# Deploy and run hooks
tuckr set <group>

# Check status of all groups
tuckr status
```

## Directory Structure

<br />

```
<dotfiles-repo>/
├── Configs/          # Dotfiles organized by program/group
├── Hooks/            # Pre/post deployment scripts
├── tests/            # Docker integration tests
├── setup             # Automated setup script
└── Dockerfile        # Linux integration test container
```

The repo can be cloned anywhere. The `setup-tuckr-symlink.sh` script creates a platform-specific symlink from Tuckr's expected location to your actual repo path.

The setup flow layers metadata on top of Tuckr conventions:

- `Configs/<group>/` still defines the deployable Tuckr group
- `Hooks/<group>/pre.sh|post.sh|rm.sh` still define actual Tuckr hooks
- `Configs/<group>.group.toml` adds setup-only metadata such as descriptions and dependency ordering

## Available Groups

<br />

### Shell & Terminal

<br />

#### `nushell`

**Location:** `Configs/nushell/.config/nushell/` **Deploys:** `~/.config/nushell/` **Description:** Nushell shell configuration including env.nu, config.nu, login.nu, and custom modules (secrets, direnv).

**Hook:** `post_nushell` - Generates vendor autoload scripts (starship, carapace, atuin, mise, zoxide), sets nushell as default shell via chsh, creates macOS config symlink

#### `zellij`

**Location:** `Configs/zellij/.config/zellij/` **Deploys:** `~/.config/zellij/` **Description:** Zellij terminal multiplexer configuration and layouts.

#### `ghostty`

**Location:** `Configs/ghostty/.config/ghostty/` **Deploys:** `~/.config/ghostty/` **Description:** Ghostty terminal emulator configuration.

### Editors

<br />

#### `helix`

**Location:** `Configs/helix/.config/helix/` **Deploys:** `~/.config/helix/` **Description:** Helix editor configuration including config.toml, languages.toml, languages/ directory, and Steel plugin scripts (helix.scm, init.scm).

#### `scripts`

**Location:** `Configs/scripts/.local/bin/` **Deploys:** `~/.local/bin/` **Description:** Custom utility scripts including:

- `dot rebuild` - Cross-platform system rebuild (`nh darwin switch` on macOS, `nh home switch` on Linux); successful runs also sync managed global pnpm packages, and `dot rebuild --update` refreshes `flake.lock` plus managed external agent skills before rebuilding
- `generate-machine-config` - Auto-detect and generate machine.nix for Nix configuration
- `update:node` - Update Node.js to latest version using pnpm env
- `pnpm:global:sync` - Install the managed pnpm global project packages
- `pnpm:global:add/remove/update/list` - Manage packages in the pnpm global project
- `install:helix:custom` - Build Helix with Steel plugin support
- `setup:env` - Manage the optional `.env.dotfiles` fallback for `OP_SERVICE_ACCOUNT_TOKEN`
- `ci_check` - Run local CI checks before pushing (formatting, shellcheck, nushell, nix)
- `tuckr:reload` - Non-destructive reload of all tuckr groups; the Nix group uses `tuckr add --only-files`, so it only reconciles symlinks and leaves packages and the tracked `flake.lock` unchanged
- `tuckr:redeploy` - Full forced redeploy of all tuckr groups in consistent order (nix first, then alphabetical, then late groups)
- `commands` - List all custom scripts with descriptions
- `test_scripts` - Run the test suite for nushell scripts

### Development Tools

<br />

#### `nix`

**Location:** `Configs/nix/.config/nix/` **Deploys:** `~/.config/nix/` **Description:** Nix system configuration including flake.nix, darwin.nix, and home.nix. Uses nix-darwin on macOS, standalone home-manager on Linux.

**Hook:** `post_nix` - Automatically rebuilds system configuration after deployment

#### `direnv`

**Location:** `Configs/direnv/.config/direnv/` **Deploys:** `~/.config/direnv/` **Description:** Directory-specific environment variable management.

#### `pnpm`

**Location:** `Configs/pnpm/.config/pnpm-global/` **Deploys:** `~/.config/pnpm-global/` **Description:** Managed pnpm project (`package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`) for deterministic CLI tool installs on macOS and Linux.

**Hook:** `post_pnpm` - Runs `pnpm:global:sync`, which links the managed manifests into `~/.local/share/pnpm-global` and installs there with normal `pnpm install` semantics. Shell startup adds `~/.local/share/pnpm-global/node_modules/.bin` to PATH.

Pi remains installed through the managed pnpm packages, but `~/.pi/` is intentionally user-managed instead of synced by Tuckr.

#### `dprint`

**Location:** `Configs/dprint/` **Deploys:** `~/dprint.json` **Description:** Code formatter configuration for multiple languages.

#### `kdl`

**Location:** `Configs/kdl/.config/kdl/` **Deploys:** `~/.config/kdl/` **Description:** KDL document formatter configuration.

### Git Tools

<br />

#### `git`

**Location:** `Configs/git/.config/git/` **Deploys:** `~/.config/git/` **Description:** Portable Git main and aliases config files. The `Hooks/git/post.sh` hook ensures `~/.gitconfig` starts with a managed autogenerated include block for these shared files while keeping `~/.gitconfig` itself untracked and undeployed by Tuckr.

#### `lazygit`

**Location:** `Configs/lazygit/.config/lazygit/` **Deploys:** `~/.config/lazygit/` **Description:** Terminal UI for git commands configuration.

## Hooks System

<br />

Tuckr supports hooks that run at different stages of deployment:

### Active Hooks

<br />

- **`Hooks/git/post.sh`**: Ensures `~/.gitconfig` starts with a managed autogenerated block that includes the shared `~/.config/git/main` and `~/.config/git/aliases` files
- **`Hooks/nix/post.sh`**: Rebuilds system after nix config changes (`nh darwin switch` on macOS, `nh home switch` on Linux), auto-generates machine.nix if missing
- **`Hooks/nushell/post.sh`**: Generates vendor autoload scripts, sets nushell as default shell, creates macOS config symlink
- **`Hooks/pnpm/post.sh`**: Syncs managed pnpm global manifests and installs global packages with lockfile enforcement

### Hook Naming Convention

<br />

Hooks are organized as `Hooks/<group>/<type>.sh`:

- `pre.sh`: Runs before symlinking
- `post.sh`: Runs after symlinking
- `rm.sh`: Runs during removal

Only executable hook scripts need `chmod +x`. Setup metadata lives in sidecar TOML files such as `Configs/nix.group.toml` and is not executed by Tuckr directly.

## Common Workflows

<br />

### Initial Setup (New Machine)

<br />

**Using the automated setup script (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Lite mode (skip GUI-heavy applications)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --lite
```

**Or manually with Tuckr:**

```bash
# First, ensure the repository is cloned and Tuckr symlink is set up
# (The setup script handles this automatically)

# Deploy core groups
tuckr set nushell
tuckr add --only-files nix

# Deploy development tools
tuckr add dprint direnv git kdl lazygit

# Ensure shared Git config includes are installed
# The git hook updates ~/.gitconfig and keeps the tracked files in ~/.config/git/
tuckr set git

# Deploy terminal environment
tuckr add zellij

# Verify everything
tuckr status
```

### Adding a New Dotfile

<br />

```bash
# Create group directory structure (from your dotfiles repo root)
mkdir -p Configs/newtool/.config/newtool

# Add your config files to Configs/newtool/
# Files should mirror your home directory structure

# Deploy the group
tuckr add newtool
```

### Updating Existing Configuration

<br />

Dotfiles are symlinked, so changes are immediate:

```bash
# Edit file directly in your dotfiles repo
vim Configs/nushell/.config/nushell/config.nu

# Or edit via symlink in home directory
vim ~/.config/nushell/config.nu

# Changes are automatically reflected (same file via symlink)
```

### Environment Variables Setup

<br />

Dotfiles secrets are declared in `~/monosecret.toml` and resolved lazily from Monosecret + 1Password.

```bash
ms check          # verify declared secrets
msr --reason "<why>" <command> # inject secrets into one command
msload --reason "<why>"        # load secrets into the current shell session
```

`~/.env.dotfiles` is no longer the primary secret store. It is only an optional fallback for `OP_SERVICE_ACCOUNT_TOKEN` when keyring/keychain is unavailable or being reset.

```bash
setup:env             # create/verify the optional fallback file
setup:env --set-token # store OP_SERVICE_ACCOUNT_TOKEN in that fallback file
```

**Note:** The `.env.dotfiles` fallback file is created from `Configs/monosecret/.env.dotfiles.example` when you deploy the `monosecret` group.

### Removing a Configuration

<br />

```bash
# Remove symlinks for a group
tuckr rm groupname

# To delete the group entirely (from your dotfiles repo root)
rm -rf Configs/groupname
```

## Platform-Specific Groups

<br />

The `nix` group deploys on all platforms, using nix-darwin on macOS and standalone home-manager on Linux.

Other groups with `_macos`, `_linux`, or `_windows` suffixes only deploy on matching platforms.

## Tuckr vs Stow

<br />

This repository was migrated from GNU Stow. Key differences:

| Feature          | Stow               | Tuckr                     |
| ---------------- | ------------------ | ------------------------- |
| Structure        | Package root       | Configs/ subdirectory     |
| Ignore files     | `.stow-*-ignore`   | None (keep repo clean)    |
| Hooks            | Not supported      | Pre/post/rm hooks         |
| Platform support | Manual scripting   | Built-in suffix detection |
| Configuration    | Command-line flags | Convention-based          |

## Access Location

<br />

Tuckr expects dotfiles at a platform-specific path. The `setup-tuckr-symlink.sh` script creates a symlink:

```
~/Library/Application Support/dotfiles → <your-dotfiles-repo>  (macOS)
~/.config/dotfiles → <your-dotfiles-repo>                      (Linux/BSD)
```

You can edit files from either location (they're the same directory via symlink).

## Troubleshooting

<br />

### Symlink Conflicts

<br />

If you see errors about existing files:

```bash
# Use force to overwrite
tuckr add --force <group>
```

### Hook Not Running

<br />

Ensure hooks are executable (from your dotfiles repo root):

```bash
chmod +x Hooks/*
```

### Group Not Found

<br />

Tuckr looks for groups in `Configs/` directory. Verify (from your dotfiles repo root):

```bash
ls Configs/
```

### Nix Flake Update Issues

<br />

**Problem: "Too many open files" error**

This error occurs when Nix hits the system's file descriptor limit during builds.

```
error: ... could not open '.../.cache/nix/tarball-cache/...': Too many open files
```

**Solution (Automatic):** The dotfiles already handle this! Just use the aliases:

```bash
# Update flake inputs
update

# Rebuild system (automatically increases ulimit before building on macOS)
dot rebuild

# Persist CLI-focused lite mode (skip GUI-heavy apps)
dot rebuild --lite

# Persist full mode (include GUI-heavy apps)
dot rebuild --no-lite

# Validate setup metadata files
./setup --validate-metadata
```

The `dot rebuild` script increases the file descriptor limit to 10,240 before running on macOS, and successful runs explicitly sync managed global pnpm packages.

**Solution (Manual rebuild on macOS):**

```bash
# Increase limit, then rebuild
ulimit -n 10240 && sudo NIX_USER_CONFIG_DIR="$HOME/.config/nix" nh darwin switch ~/.config/nix -H default --impure
```

**Why this happens:**

- Nix builds can open thousands of files simultaneously (downloading, extracting, building)
- macOS default limit is 256 open files (too low for large Nix builds)
- The limit affects both user context and sudo context

**Check your current limit:**

```bash
ulimit -n  # Should show 10240 if using this dotfiles config
```

**Problem: "$HOME is not owned by you" error**

This happens when running `nix flake update` with sudo.

**Solution:** Run `update` without sudo (the alias already does this correctly):

```bash
# Correct (no sudo)
update

# Wrong (don't do this)
sudo update
```

**Why this happens:**

- `nix flake update` needs access to YOUR user's Nix cache at ~/.cache/nix
- Running with sudo changes context to root user ($HOME becomes /var/root)
- Root can't access your user's cache, and builds may fail or use wrong paths

Or let the `post_nix` hook handle rebuilds:

```bash
tuckr set nix
```

## Nix Package Updates

<br />

Custom package definitions are maintained in the external `ifiokjr/nixpkgs` input.

Use:

```bash
dot rebuild --update
```

to update flake inputs (including `ifiokjr-nixpkgs`), refresh `flake.lock`, and sync the selected agent skills from [`cursor/plugins`](https://github.com/cursor/plugins/tree/main/pstack/skills), [`mattpocock/skills`](https://github.com/mattpocock/skills), and [`leancodepl/patrol`](https://github.com/leancodepl/patrol/tree/master/skills) before rebuilding. Resolved source commits are recorded beside the managed skills in source-specific JSON manifests; selections and coexistence boundaries are documented in [`docs/agents/skills.md`](docs/agents/skills.md).

### Node.js Version Management

<br />

Use:

```bash
update:node
```

to install/activate the latest Node.js version via `pnpm env use --global latest`.

### Global pnpm Packages

<br />

Use:

```bash
tuckr set pnpm
```

pnpm v11's special global mode is intentionally not used here: every `pnpm add -g` argument gets a generated isolated project and `pnpm install -g` cannot restore packages from a declarative manifest. Instead, this group installs the Tuckr-managed `package.json` and `pnpm-lock.yaml` as a normal pnpm project at `~/.local/share/pnpm-global`. Shell startup adds that project's `node_modules/.bin` to PATH, making its CLIs globally available while retaining one reviewable source of truth.

Sync always uses `pnpm install --frozen-lockfile --prod`; it never falls back to unlocked resolution. Direct dependencies are exact-pinned, transitive dependencies and integrity hashes come from the committed lockfile, approved lifecycle scripts are declared in `pnpm-workspace.yaml#allowBuilds`, and pnpm itself is pinned by the Nix flake.

Use `pnpm:global:add <pkg>`, `pnpm:global:remove <pkg>`, `pnpm:global:update [pkg]`, and `pnpm:global:list` to manage this project intentionally, then commit the resulting `Configs/pnpm/.config/pnpm-global/package.json` and `pnpm-lock.yaml` changes.

Successful `dot rebuild` runs invoke the same managed sync explicitly, so global CLI packages like Pi stay installed after Nix/home-manager updates.

## Testing

<br />

### Docker Integration Test

<br />

A Docker-based integration test validates the full setup + rebuild flow on Linux:

```bash
docker build -t dotfiles-test . && docker run --rm dotfiles-test
```

This builds an Ubuntu 24.04 container, runs the setup script, triggers `nh home switch` via `dot rebuild`, and verifies the result.

### Script Tests

<br />

```bash
nu Configs/scripts/.local/bin/test_scripts
```

## Resources

<br />

- [Tuckr Documentation](https://raphgl.github.io/Tuckr/)
- [Tuckr GitHub](https://github.com/RaphGL/Tuckr)
