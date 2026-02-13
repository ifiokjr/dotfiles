# Dotfiles - Tuckr Managed

This repository uses [Tuckr](https://github.com/RaphGL/Tuckr), a modern dotfile manager that creates symlinks from this repository to your home directory.

## Quick Start

### Automated Setup (Recommended)

Set up your entire environment with one command:

```bash
# Remote installation (fastest way to get started)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Or clone anywhere you like, then run locally
git clone https://github.com/ifiokjr/dotfiles.git ~/path/to/dotfiles
cd ~/path/to/dotfiles
./setup
```

The setup script handles everything: Nix installation, repository cloning, Tuckr configuration, and automatic deployment of all configuration groups.

**Setup Script Options:**

- `--groups <groups>` - Deploy only specific groups (comma-separated, otherwise deploys all)
- `--cwd <path>` - Clone to custom location (default: `~/Developer/.dotfiles`)
- `--skip-nix` - Skip Nix installation
- `--help` - Show help

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
├── Secrets/          # Encrypted files (not currently used)
└── .migration/       # Old stow files and templates
```

The repo can be cloned anywhere. The `setup-tuckr-symlink.sh` script creates a platform-specific symlink from Tuckr's expected location to your actual repo path.

## Available Groups

### Shell & Terminal

#### `nushell`

**Location:** `Configs/nushell/.config/nushell/` **Deploys:** `~/.config/nushell/` **Description:** Nushell shell configuration including env.nu, config.nu, login.nu, and custom modules (secrets, direnv).

**Hook:** `post_nushell` - Generates vendor autoload scripts (starship, carapace, atuin, mise, zoxide), sets nushell as default shell via chsh, creates macOS config symlink

#### `yazelix`

**Location:** `Configs/yazelix/.config/yazelix/` **Deploys:** `~/.config/yazelix/` **Description:** Integrated terminal environment combining Yazi (file manager), Zellij (multiplexer), and Helix (editor). Contains 82 files including shell configs, plugins, layouts, and scripts. **Note:** Kept as single group due to interdependencies between components.

#### `zellij`

**Location:** `Configs/zellij/.config/zellij/` **Deploys:** `~/.config/zellij/` **Description:** Zellij terminal multiplexer configuration and layouts.

#### `ghostty`

**Location:** `Configs/ghostty/.config/ghostty/` **Deploys:** `~/.config/ghostty/` **Description:** Ghostty terminal emulator configuration.

### Editors

#### `helix`

**Location:** `Configs/helix/.config/helix/` **Deploys:** `~/.config/helix/` **Description:** Helix editor configuration including config.toml, languages.toml, and Steel plugin scripts (helix.scm, init.scm). Runtime symlink is documented but managed separately.

#### `scripts`

**Location:** `Configs/scripts/.local/bin/` **Deploys:** `~/.local/bin/` **Description:** Custom utility scripts including:

- `install:helix:custom` - Build Helix with Steel plugin support
- `update:pnpm:version` - Automatically update pnpm-standalone to latest version (also installs latest Node.js)
- `update:node` - Update Node.js to latest version using pnpm env
- `setup:env` - Interactive environment variables setup (API keys, tokens)

#### `claude`

**Location:** `Configs/claude/.config/claude/` **Deploys:** `~/.config/claude/` **Description:** Claude Code settings including attribution preferences.

### Development Tools

#### `nix`

**Location:** `Configs/nix/.config/nix/` **Deploys:** `~/.config/nix/` **Description:** Nix system configuration including flake.nix, darwin.nix, and home.nix. Uses nix-darwin on macOS, standalone home-manager on Linux.

**Hook:** `post_nix` - Automatically rebuilds system configuration after deployment

#### `direnv`

**Location:** `Configs/direnv/.config/direnv/` **Deploys:** `~/.config/direnv/` **Description:** Directory-specific environment variable management.

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

- **`post_nix`**: Runs `rebuild` after nix config changes (darwin-rebuild on macOS, home-manager switch on Linux)
- **`post_nushell`**: Generates vendor autoload scripts, sets nushell as default shell, creates macOS config symlink

### Hook Naming Convention

- `pre_<group>`: Runs before symlinking
- `post_<group>`: Runs after symlinking
- `rm_<group>`: Runs during removal

All hooks must be executable (`chmod +x Hooks/*`).

## Common Workflows

### Initial Setup (New Machine)

**Using the automated setup script (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash
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
tuckr set yazelix  # Uses set to run dependency check hook
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

## Migration Artifacts

The `.migration/` directory contains files from the GNU Stow setup:

- `.stow-global-ignore` - Old stow ignore patterns
- `.stow-local-ignore` - Old stow ignore patterns
- `.env.dotfiles.example` - Template for environment variables

These are kept for reference but not deployed by tuckr.

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

# Rebuild Darwin system (automatically increases ulimit before building)
rebuild
```

The `rebuild` alias increases the file descriptor limit to 10,240 before running. The shell configuration sets `ulimit -n 10240` for build sessions.

**Solution (Manual rebuild):**

```bash
# Increase limit, then rebuild
ulimit -n 10240 && sudo darwin-rebuild switch --flake ~/.config/nix#$(whoami)
```

**Why this happens:**

- Nix builds can open thousands of files simultaneously (downloading, extracting, building)
- macOS default limit is 256 open files (too low for large Nix builds)
- Homebrew formula downloads in particular can exhaust the limit
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

## Custom Nix Packages

The dotfiles include custom Nix packages that aren't available in nixpkgs or have special requirements. These are located in `Configs/nix/.config/nix/packages/`.

### pnpm-standalone

A standalone version of pnpm that doesn't depend on Node.js, allowing you to use pnpm to manage Node versions.

**Why custom?** The nixpkgs pnpm package depends on Node.js, which defeats the purpose of using pnpm to manage Node versions. This custom package fetches the standalone binary directly from GitHub releases.

**Supported platforms:**

- macOS (arm64, x64)
- Linux (arm64, x64)

**Current version:** 10.28.2 (January 26, 2026)

#### Updating pnpm Version

**Easiest Method (Recommended):**

Simply run:

```bash
update:pnpm:version
```

This script automatically:

- Fetches the latest pnpm version from GitHub releases
- Updates `pnpm-standalone.nix` with the new version
- Detects your platform (macos-arm64, macos-x64, etc.)
- Fetches and updates the correct hash
- Rebuilds your Darwin configuration
- Verifies pnpm is installed correctly
- Installs the latest Node.js version using pnpm env

**Advanced Method:**

If you only need to update the hash for the current version (doesn't require sudo):

```bash
cd ~/.config/nix/packages
./update-pnpm-hash.sh
# Then run: rebuild
```

**Manual Method:**

If you prefer full manual control:

1. Edit `Configs/nix/.config/nix/packages/pnpm-standalone.nix`
2. Update the `version` variable (e.g., `version = "10.29.0";`)
3. Set the hash for your platform to `lib.fakeSha256`:
   ```nix
   hashes = {
     "macos-arm64" = lib.fakeSha256;  # Or whichever platform you're on
     # ...
   };
   ```
4. Run `rebuild`
5. The build will fail with an error showing the correct hash:
   ```
   error: hash mismatch in fixed-output derivation '/nix/store/...'
     specified: sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
     got:      sha256-3NKbhDlzXW0IUJL+Yoj0vKRfdmHCNYVP9Q4Q8OvGXV8=
   ```
6. Copy the "got" hash and update your platform entry in `pnpm-standalone.nix`
7. Run `rebuild` again

**Troubleshooting:**

If any script fails:

- Check the output for error messages
- Verify you have internet access (scripts need to fetch from GitHub)
- Try the manual method above

### Node.js Version Management

Since pnpm-standalone doesn't depend on Node.js, you can use pnpm itself to manage Node.js versions. This gives you full control over which Node.js version to use.

**Update Node.js to latest version:**

```bash
update:node
```

This script uses `pnpm env use --global latest` to install and activate the latest stable Node.js version.

**Manual Node.js management:**

```bash
# Install latest Node.js
pnpm env use --global latest

# Install specific version
pnpm env use --global 20

# List installed versions
pnpm env list

# Remove a version
pnpm env remove --global 18
```

**Note:** The `update:pnpm:version` script automatically installs the latest Node.js after updating pnpm, so you typically don't need to run `update:node` separately.

For more details about the custom package system, see `Configs/nix/.config/nix/packages/readme.md`.

## Resources

- [Tuckr Documentation](https://raphgl.github.io/Tuckr/)
- [Tuckr GitHub](https://github.com/RaphGL/Tuckr)
- [Yazelix Documentation](~/.config/yazelix/readme.md)

## Backup

A backup of the pre-migration setup exists at:

```
~/.dotfiles.backup.pre-tuckr
```

This contains the original GNU Stow structure and can be safely deleted once you've verified the migration.
