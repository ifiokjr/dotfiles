# Dotfiles - Tuckr Managed

This repository uses [Tuckr](https://github.com/RaphGL/Tuckr), a modern dotfile manager that creates symlinks from this repository to your home directory.

## Quick Start

### Automated Setup (Recommended)

Set up your entire environment with one command:

```bash
# Remote installation (fastest way to get started)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Or clone first, then run locally
git clone https://github.com/ifiokjr/dotfiles.git ~/Developer/.dotfiles
cd ~/Developer/.dotfiles
./setup
```

The setup script handles everything: Nix installation, repository cloning, Tuckr configuration, and automatic deployment of all configuration groups.

**Setup Script Options:**
- `--groups <groups>` - Deploy only specific groups (comma-separated, otherwise deploys all)
- `--cwd <path>` - Clone to custom location (default: ~/Developer/.dotfiles)
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
~/Library/Application Support/dotfiles/
├── Configs/          # Dotfiles organized by program/group
├── Hooks/            # Pre/post deployment scripts
├── Secrets/          # Encrypted files (not currently used)
└── .migration/       # Old stow files and templates
```

## Available Groups

### Shell & Terminal

#### `zsh_macos` (Platform-specific)
**Location:** `Configs/zsh_macos/`
**Deploys:** `~/.zshrc`
**Description:** Zsh shell configuration with yazelix integration and macOS-specific settings.
**Platform:** macOS only (won't deploy on Linux/Windows)

**Hook:** `post_zsh_macos` - Reminds you to reload shell after deployment

#### `yazelix`
**Location:** `Configs/yazelix/.config/yazelix/`
**Deploys:** `~/.config/yazelix/`
**Description:** Integrated terminal environment combining Yazi (file manager), Zellij (multiplexer), and Helix (editor). Contains 82 files including shell configs, plugins, layouts, and scripts.
**Note:** Kept as single group due to interdependencies between components.

**Hook:** `pre_yazelix` - Verifies dependencies (zellij, yazi, hx) are installed

#### `zellij`
**Location:** `Configs/zellij/.config/zellij/`
**Deploys:** `~/.config/zellij/`
**Description:** Zellij terminal multiplexer configuration and layouts.

### Editors

#### `helix`
**Location:** `Configs/helix/.config/helix/`
**Deploys:** `~/.config/helix/`
**Description:** Helix editor configuration including config.toml, languages.toml, and Steel plugin scripts (helix.scm, init.scm). Runtime symlink is documented but managed separately.

#### `scripts`
**Location:** `Configs/scripts/.local/bin/`
**Deploys:** `~/.local/bin/`
**Description:** Custom utility scripts including `install:helix:custom` for building Helix with Steel plugin support.

### Development Tools

#### `nix_macos` (Platform-specific)
**Location:** `Configs/nix_macos/.config/nix/`
**Deploys:** `~/.config/nix/`
**Description:** Nix Darwin system configuration including flake.nix, darwin.nix, and home.nix.
**Platform:** macOS only (Darwin-specific)

**Hook:** `post_nix_macos` - Automatically rebuilds Darwin configuration after deployment

#### `direnv`
**Location:** `Configs/direnv/.config/direnv/`
**Deploys:** `~/.config/direnv/`
**Description:** Directory-specific environment variable management.

#### `dprint`
**Location:** `Configs/dprint/`
**Deploys:** `~/dprint.json`
**Description:** Code formatter configuration for multiple languages.

#### `kdl`
**Location:** `Configs/kdl/.config/kdl/`
**Deploys:** `~/.config/kdl/`
**Description:** KDL document formatter configuration.

### Git Tools

#### `lazygit`
**Location:** `Configs/lazygit/.config/lazygit/`
**Deploys:** `~/.config/lazygit/`
**Description:** Terminal UI for git commands configuration.

## Hooks System

Tuckr supports hooks that run at different stages of deployment:

### Active Hooks

- **`post_nix_macos`**: Runs `darwin-rebuild switch` after nix config changes
- **`pre_yazelix`**: Checks for yazelix dependencies (zellij, yazi, hx)
- **`post_zsh_macos`**: Reminds you to reload shell configuration

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
tuckr add zsh_macos nix_macos

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
# Create group directory structure
cd ~/Library/Application\ Support/dotfiles
mkdir -p Configs/newtool/.config/newtool

# Add your config files to Configs/newtool/
# Files should mirror your home directory structure

# Deploy the group
tuckr add newtool
```

### Updating Existing Configuration

Dotfiles are symlinked, so changes are immediate:

```bash
# Edit file directly in Configs directory
vim ~/Library/Application\ Support/dotfiles/Configs/zsh_macos/.zshrc

# Or edit via symlink in home directory
vim ~/.zshrc

# Changes are automatically reflected (same file via symlink)
```

### Removing a Configuration

```bash
# Remove symlinks for a group
tuckr rm groupname

# To delete the group entirely
rm -rf ~/Library/Application\ Support/dotfiles/Configs/groupname
```

## Platform-Specific Groups

Groups with `_macos`, `_linux`, or `_windows` suffixes only deploy on matching platforms:

- `zsh_macos` - Only deploys on macOS
- `nix_macos` - Only deploys on macOS (uses nix-darwin)

This prevents incompatible configs from being deployed when cloning to different systems.

## Tuckr vs Stow

This repository was migrated from GNU Stow. Key differences:

| Feature | Stow | Tuckr |
|---------|------|-------|
| Structure | Package root | Configs/ subdirectory |
| Ignore files | `.stow-*-ignore` | None (keep repo clean) |
| Hooks | Not supported | Pre/post/rm hooks |
| Platform support | Manual scripting | Built-in suffix detection |
| Configuration | Command-line flags | Convention-based |

## Access Location

For easier access, a symlink exists at:
```
~/Developer/.dotfiles → ~/Library/Application Support/dotfiles
```

Use whichever path is more convenient.

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

Ensure hooks are executable:
```bash
chmod +x ~/Library/Application\ Support/dotfiles/Hooks/*
```

### Group Not Found

Tuckr looks for groups in `Configs/` directory. Verify:
```bash
ls ~/Library/Application\ Support/dotfiles/Configs/
```

### Nix Flake Issues

After updating nix configs, rebuild Darwin:
```bash
sudo darwin-rebuild switch --flake ~/.config/nix
```

Or let the `post_nix_macos` hook handle it:
```bash
tuckr set nix_macos
```

## Resources

- [Tuckr Documentation](https://raphgl.github.io/Tuckr/)
- [Tuckr GitHub](https://github.com/RaphGL/Tuckr)
- [Yazelix Documentation](~/.config/yazelix/README.md)

## Backup

A backup of the pre-migration setup exists at:
```
~/.dotfiles.backup.pre-tuckr
```

This contains the original GNU Stow structure and can be safely deleted once you've verified the migration.
