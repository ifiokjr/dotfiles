# Dotfiles - Tuckr Managed

This repository uses [Tuckr](https://github.com/RaphGL/Tuckr), a modern dotfile manager that creates symlinks from this repository to your home directory.

## Quick Start

For the canonical onboarding flow, start with [docs/getting-started.md](docs/getting-started.md). It now includes opinionated starter workflows for common goals such as a core shell/editor setup, a full workstation install, CI mode, and incremental Nix + Nushell adoption.

### Automated Setup (Recommended)

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
- `--groups <groups>` - Deploy only specific groups (comma-separated, otherwise deploys all)
- `--cwd <path>` - Clone to custom location (default: `~/Developer/.dotfiles`)
- `--skip-nix` - Skip Nix installation
- `--lite` - Enable CLI-focused install and skip GUI-heavy applications
- `--doctor` - Run preflight checks without changing the machine
- `--validate-metadata` - Validate `Configs/*.group.toml` files and exit
- `--dry-run` - Print the setup execution plan and exit
- `--list-groups` - List available configuration groups
- `--explain-group <name>` - Show details for one configuration group
- `--help` - Show help

### Presets

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
```

The setup script now prints an execution plan before meaningful deployment work begins so you can see the platform, repository action, bootstrap tools, groups, and hook-bearing groups ahead of time.

### Manual Tuckr Commands

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

### Shell & Terminal

#### `nushell`

**Location:** `Configs/nushell/.config/nushell/` **Deploys:** `~/.config/nushell/` **Description:** Nushell shell configuration including env.nu, config.nu, login.nu, and custom modules (secrets, direnv).

**Hook:** `post_nushell` - Generates vendor autoload scripts (starship, carapace, atuin, mise, zoxide), sets nushell as default shell via chsh, creates macOS config symlink

#### `zellij`

**Location:** `Configs/zellij/.config/zellij/` **Deploys:** `~/.config/zellij/` **Description:** Zellij terminal multiplexer configuration and layouts.

#### `ghostty`

**Location:** `Configs/ghostty/.config/ghostty/` **Deploys:** `~/.config/ghostty/` **Description:** Ghostty terminal emulator configuration.

### Editors

#### `helix`

**Location:** `Configs/helix/.config/helix/` **Deploys:** `~/.config/helix/` **Description:** Helix editor configuration including config.toml, languages.toml, languages/ directory, and Steel plugin scripts (helix.scm, init.scm).

#### `scripts`

**Location:** `Configs/scripts/.local/bin/` **Deploys:** `~/.local/bin/` **Description:** Custom utility scripts including:

- `rebuild` - Cross-platform system rebuild (darwin-rebuild on macOS, home-manager switch on Linux); successful runs also sync managed global pnpm packages, and `rebuild --update` refreshes `flake.lock` before rebuilding
- `generate-machine-config` - Auto-detect and generate machine.nix for Nix configuration
- `update:node` - Update Node.js to latest version using pnpm env
- `pnpm:global:sync` - Symlink global pnpm manifests and install pinned global packages
- `install:helix:custom` - Build Helix with Steel plugin support
- `setup:env` - Interactive environment variables setup (API keys, tokens)
- `ci_check` - Run local CI checks before pushing (formatting, shellcheck, nushell, nix)
- `commands` - List all custom scripts with descriptions
- `test_scripts` - Run the test suite for nushell scripts

#### `claude`

**Location:** `Configs/claude/` **Deploys:** `~/.claude/` and `~/.config/claude/` **Description:** Claude Code settings including attribution preferences and MCP server for tart VM control.

**Hook:** `post_claude` - Registers tart-vm MCP server with Claude Code, caches Deno dependencies

### Development Tools

#### `nix`

**Location:** `Configs/nix/.config/nix/` **Deploys:** `~/.config/nix/` **Description:** Nix system configuration including flake.nix, darwin.nix, and home.nix. Uses nix-darwin on macOS, standalone home-manager on Linux.

**Hook:** `post_nix` - Automatically rebuilds system configuration after deployment

#### `direnv`

**Location:** `Configs/direnv/.config/direnv/` **Deploys:** `~/.config/direnv/` **Description:** Directory-specific environment variable management.

#### `pnpm`

**Location:** `Configs/pnpm/.config/pnpm-global/` **Deploys:** `~/.config/pnpm-global/` **Description:** Managed global pnpm manifest (`package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`) for deterministic global package installs on macOS and Linux.

**Hook:** `post_pnpm` - Resolves pnpm's active global directory and symlinks/installs the managed global package set.

#### `pi`

**Location:** `Configs/pi/.pi/` **Deploys:** `~/.pi/` **Description:** Pi coding agent configuration including global settings, keybindings, package sources, and symlinked custom skills.

#### `dprint`

**Location:** `Configs/dprint/` **Deploys:** `~/dprint.json` **Description:** Code formatter configuration for multiple languages.

#### `kdl`

**Location:** `Configs/kdl/.config/kdl/` **Deploys:** `~/.config/kdl/` **Description:** KDL document formatter configuration.

### Git Tools

#### `lazygit`

**Location:** `Configs/lazygit/.config/lazygit/` **Deploys:** `~/.config/lazygit/` **Description:** Terminal UI for git commands configuration.

## Hooks System

Tuckr supports hooks that run at different stages of deployment:

### Active Hooks

- **`Hooks/nix/post.sh`**: Rebuilds system after nix config changes (darwin-rebuild on macOS, home-manager switch on Linux), auto-generates machine.nix if missing
- **`Hooks/nushell/post.sh`**: Generates vendor autoload scripts, sets nushell as default shell, creates macOS config symlink
- **`Hooks/claude/post.sh`**: Registers tart-vm MCP server with Claude Code, caches Deno dependencies
- **`Hooks/pnpm/post.sh`**: Syncs managed pnpm global manifests and installs global packages with lockfile enforcement

### Hook Naming Convention

Hooks are organized as `Hooks/<group>/<type>.sh`:

- `pre.sh`: Runs before symlinking
- `post.sh`: Runs after symlinking
- `rm.sh`: Runs during removal

Only executable hook scripts need `chmod +x`. Setup metadata lives in sidecar TOML files such as `Configs/nix.group.toml` and is not executed by Tuckr directly.

## Common Workflows

### Initial Setup (New Machine)

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
tuckr add nix

# Deploy development tools
tuckr add dprint direnv kdl lazygit

# Deploy terminal environment
tuckr add zellij

# Verify everything
tuckr status
```

### Adding a New Dotfile

```bash
# Create group directory structure (from your dotfiles repo root)
mkdir -p Configs/newtool/.config/newtool

# Add your config files to Configs/newtool/
# Files should mirror your home directory structure

# Deploy the group
tuckr add newtool
```

### Updating Existing Configuration

Dotfiles are symlinked, so changes are immediate:

```bash
# Edit file directly in your dotfiles repo
vim Configs/nushell/.config/nushell/config.nu

# Or edit via symlink in home directory
vim ~/.config/nushell/config.nu

# Changes are automatically reflected (same file via symlink)
```

### Environment Variables Setup

Configure API keys and tokens for various services using the interactive setup script:

```bash
setup:env
```

**What it does:**

- Guides you through setting up each API key/token interactively
- Provides descriptions and links for obtaining each key
- Creates/updates `~/.env.dotfiles` with your values
- Sets secure file permissions (600 - read/write for user only)
- Backs up existing file before updating
- Allows you to skip any keys you don't need

**Supported environment variables:**

- **GITHUB_TOKEN** - GitHub personal access token ([Get it](https://github.com/settings/tokens/new))
- **OPENAI_API_KEY** - OpenAI API key for GPT, DALL-E, etc. ([Get it](https://platform.openai.com/api-keys))
- **ANTHROPIC_API_KEY** - Anthropic Claude API key ([Get it](https://console.anthropic.com/settings/keys))
- **DISCORD_TOKEN** - Discord bot token ([Get it](https://discord.com/developers/applications))
- **GOOGLE_API_KEY** - Google Cloud API key ([Get it](https://console.cloud.google.com/apis/credentials))
- **REPLICATE_API_TOKEN** - Replicate AI token ([Get it](https://replicate.com/account/api-tokens))
- **HUGGING_FACE_TOKEN** - Hugging Face access token ([Get it](https://huggingface.co/settings/tokens))

**Features:**

- Shows masked current values when updating
- Confirms each value before saving
- Option to keep existing values
- Creates automatic backups with timestamp

**Manual setup:** You can also edit `~/.env.dotfiles` directly:

```bash
vim ~/.env.dotfiles
# Then open a new terminal to reload
```

**Note:** The `.env.dotfiles` file is automatically created from a template when you first deploy the `nushell` group via the post-deployment hook.

### Removing a Configuration

```bash
# Remove symlinks for a group
tuckr rm groupname

# To delete the group entirely (from your dotfiles repo root)
rm -rf Configs/groupname
```

## Platform-Specific Groups

The `nix` group deploys on all platforms, using nix-darwin on macOS and standalone home-manager on Linux.

Other groups with `_macos`, `_linux`, or `_windows` suffixes only deploy on matching platforms.

## Tuckr vs Stow

This repository was migrated from GNU Stow. Key differences:

| Feature          | Stow               | Tuckr                     |
| ---------------- | ------------------ | ------------------------- |
| Structure        | Package root       | Configs/ subdirectory     |
| Ignore files     | `.stow-*-ignore`   | None (keep repo clean)    |
| Hooks            | Not supported      | Pre/post/rm hooks         |
| Platform support | Manual scripting   | Built-in suffix detection |
| Configuration    | Command-line flags | Convention-based          |

## Access Location

Tuckr expects dotfiles at a platform-specific path. The `setup-tuckr-symlink.sh` script creates a symlink:

```
~/Library/Application Support/dotfiles → <your-dotfiles-repo>  (macOS)
~/.config/dotfiles → <your-dotfiles-repo>                      (Linux/BSD)
```

You can edit files from either location (they're the same directory via symlink).

## Troubleshooting

### Symlink Conflicts

If you see errors about existing files:

```bash
# Use force to overwrite
tuckr add --force <group>
```

### Hook Not Running

Ensure hooks are executable (from your dotfiles repo root):

```bash
chmod +x Hooks/*
```

### Group Not Found

Tuckr looks for groups in `Configs/` directory. Verify (from your dotfiles repo root):

```bash
ls Configs/
```

### Nix Flake Update Issues

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
rebuild

# Persist CLI-focused lite mode (skip GUI-heavy apps)
rebuild --lite

# Persist full mode (include GUI-heavy apps)
rebuild --no-lite

# Validate setup metadata files
./setup --validate-metadata
```

The `rebuild` script increases the file descriptor limit to 10,240 before running on macOS, and successful runs explicitly sync managed global pnpm packages.

**Solution (Manual rebuild on macOS):**

```bash
# Increase limit, then rebuild
ulimit -n 10240 && sudo darwin-rebuild switch --flake ~/.config/nix#default --impure
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

Custom package definitions are maintained in the external `ifiokjr/nixpkgs` input.

Use:

```bash
rebuild --update
```

to update flake inputs (including `ifiokjr-nixpkgs`) and refresh `flake.lock` before rebuilding.

### Node.js Version Management

Use:

```bash
update:node
```

to install/activate the latest Node.js version via `pnpm env use --global latest`.

### Global pnpm Packages

Use:

```bash
tuckr set pnpm
```

to sync `~/.config/pnpm-global` into pnpm's active global directory (resolved from `pnpm root -g`) and install packages from the committed lockfile.

The sync script also strips pnpm-generated `dependenciesMeta.*.node` entries from the managed manifest and lockfile, so machine-specific Node.js paths are not committed.

Successful `rebuild` runs invoke the same managed sync explicitly, so global CLI packages like Pi stay installed after Nix/home-manager updates.

## Testing

### Docker Integration Test

A Docker-based integration test validates the full setup + rebuild flow on Linux:

```bash
docker build -t dotfiles-test . && docker run --rm dotfiles-test
```

This builds an Ubuntu 24.04 container, runs the setup script, triggers `home-manager switch` via `rebuild`, and verifies the result.

### Script Tests

```bash
nu Configs/scripts/.local/bin/test_scripts
```

## Resources

- [Tuckr Documentation](https://raphgl.github.io/Tuckr/)
- [Tuckr GitHub](https://github.com/RaphGL/Tuckr)
