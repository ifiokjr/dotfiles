# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Tuckr-managed dotfiles repository** that uses symlinks to deploy configuration files to the home directory. The repo can be cloned anywhere on disk. Tuckr expects dotfiles at platform-specific locations (e.g., `~/Library/Application Support/dotfiles` on macOS), so `setup-tuckr-symlink.sh` auto-detects the repo location and creates the necessary symlink.

**Key characteristics:**

- Platform-aware deployment (macOS, Linux, BSD, Windows)
- Modular configuration groups
- Hook-based automation
- Nix-first philosophy with reproducible environments

## Initial Setup

### Automated Setup (Recommended)

The easiest way to set up your environment is using the automated setup script:

```bash
# Remote installation (on a new machine)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup.sh | bash

# Or clone anywhere, then run locally
git clone https://github.com/ifiokjr/dotfiles.git ~/path/to/dotfiles
cd ~/path/to/dotfiles
./setup
```

The setup script will:

1. Install Determinate Nix (if not present)
2. Clone the dotfiles repository (if running remotely)
3. Set up Tuckr symlinks via `setup-tuckr-symlink.sh`
4. Automatically deploy all configuration groups
5. Clean up temporary packages

**Options:**

- `--cwd PATH` - Clone dotfiles to custom path (default: current directory or `~/Developer/.dotfiles`)
- `--groups GROUPS` - Deploy only specific comma-separated groups (otherwise deploys all)
- `--skip-nix` - Skip Nix installation if already installed
- `--help` - Show help message

### Manual Setup

If you prefer manual setup:

```bash
# First time setup - creates platform-specific symlink
./setup-tuckr-symlink.sh

# Deploy configuration groups
tuckr set nushell                    # Shell config (runs hooks)
tuckr add nix                        # Nix system configs (all platforms)
tuckr add dprint direnv kdl lazygit  # Development tools
tuckr add zellij                  # Terminal multiplexer

# Verify deployment
tuckr status
```

## Common Commands

### Tuckr Commands

```bash
tuckr add <group>              # Deploy a configuration group (create symlinks)
tuckr add --force <group>      # Deploy with overwrite of existing files
tuckr rm <group>               # Remove symlinks for a group
tuckr set <group>              # Deploy and run hooks (preferred for groups with hooks)
tuckr status                   # Check deployment status of all groups
```

### Nix Commands

```bash
# Rebuild system configuration (automatically runs via post_nix hook)
# macOS: darwin-rebuild switch, Linux: home-manager switch
rebuild

# Or let the hook handle it
tuckr set nix
```

### Configuration Updates

Since files are symlinked, edits are immediate:

```bash
# Edit via symlink in home directory
vim ~/.config/nushell/config.nu

# Or edit directly in your dotfiles repo
vim <dotfiles-repo>/Configs/nushell/.config/nushell/config.nu

# Changes are reflected instantly (same file via symlink)
```

## Configuration Groups

The repository contains 9 configuration groups organized in `Configs/`:

| Group       | Files | Platform | Purpose                                  | Hook           |
| ----------- | ----- | -------- | ---------------------------------------- | -------------- |
| **nix**     | 6     | All      | System configuration with Nix flakes     | `post_nix`     |
| **nushell** | 6     | All      | Nushell shell configuration & modules    | `post_nushell` |
| **ghostty** | 1     | All      | Ghostty terminal emulator config         | None           |
| **zellij**  | 4     | All      | Terminal multiplexer config & layouts    | None           |
| **claude**  | 1     | All      | Claude Code settings (attribution, etc.) | None           |
| **direnv**  | 1     | All      | Directory-specific environment variables | None           |
| **dprint**  | 1     | All      | Multi-language code formatter            | None           |
| **kdl**     | 1     | All      | KDL document formatter                   | None           |
| **lazygit** | 1     | All      | Git TUI configuration                    | None           |

**Platform-specific groups** (suffixed with `_macos`, `_linux`, etc.) only deploy on matching platforms.

## Architecture

### Directory Structure

```
<dotfiles-repo>/
├── Configs/                    # Configuration groups
│   ├── nix/                   # Nix system config (darwin + home-manager)
│   ├── nushell/               # Nushell shell config
│   ├── ghostty/               # Ghostty terminal config
│   ├── zellij/                # Terminal multiplexer
│   ├── claude/                # Claude Code settings
│   ├── direnv/                # Environment management
│   ├── dprint/                # Code formatter
│   ├── kdl/                   # KDL formatter
│   └── lazygit/               # Git TUI
├── Hooks/                      # Pre/post deployment scripts
│   ├── nix/post.sh            # Rebuilds system after Nix changes
│   └── nushell/post.sh        # Generates vendor autoload, sets default shell
├── setup-tuckr-symlink.sh     # Bootstrap script for platform symlink
└── readme.md                   # Full documentation
```

### Deployment Pattern

Each group follows XDG Base Directory conventions:

```
Configs/[group]/
├── .config/[tool]/           # Deploys to ~/.config/[tool]/
│   └── [config files]
└── [root files]              # Deploys to ~/
```

Example: `Configs/dprint/dprint.json` → `~/dprint.json`

### Hooks System

Hooks are executable bash scripts in `Hooks/` directory:

Hooks are organized as `Hooks/<group>/pre.sh`, `Hooks/<group>/post.sh`, or `Hooks/<group>/rm.sh`:

**Active hooks:**

1. **`Hooks/nix/post.sh`** - Automatically rebuilds system configuration after Nix config deployment (darwin-rebuild on macOS, home-manager switch on Linux)
2. **`Hooks/nushell/post.sh`** - Generates vendor autoload scripts (starship, carapace, atuin, mise, zoxide), sets nushell as default shell via chsh, creates macOS config symlink

## Nushell Development Notes

**CRITICAL: Escape parentheses in string interpolation:** Use `\(` and `\)` (single backslash)

- ✅ Correct: `$"Checking pane \(editor\)"`
- ❌ Wrong: `$"Checking pane \\(editor\\)"` - tries to execute command
- ❌ Wrong: `$"Checking pane (editor)"` - executes command substitution
- Unescaped parentheses trigger command substitution
- "Command not found" errors in strings usually indicate incorrect escaping

## Nix System Configuration

The `nix` group contains a complete Nix system configuration with integrated Home Manager (nix-darwin on macOS, standalone home-manager on Linux).

### Key Files

- **`flake.nix`** - Main flake defining Darwin and Home Manager configurations
- **`darwin.nix`** - Darwin-specific system settings
- **`home.nix`** - Home Manager user configuration

### Features

- User-specific configurations (currently configured for `ifiokjr`)
- Nix Homebrew integration with declarative tap management
- Integrated Home Manager (no separate invocation needed)

### Build Commands

```bash
# Primary method (on macOS)
darwin-rebuild switch --flake ~/.config/nix#$(whoami)

# Alternative with auto-detection (impure)
darwin-rebuild switch --flake ~/.config/nix# --impure

# Standalone Home Manager (Linux or standalone)
home-manager switch --flake ~/.config/nix#username@system
# Example: home-manager switch --flake ~/.config/nix#ifiokjr@x86_64-linux
```

### Adding New Users

Edit `flake.nix` and add new configurations:

```nix
darwinConfigurations.newuser = mkDarwinConfig {
  system = "aarch64-darwin";
  username = "newuser";
};
```

## Development Workflow

### Adding a New Configuration Group

```bash
# Create group directory structure (from your dotfiles repo root)
mkdir -p Configs/newtool/.config/newtool

# Add config files (mirror home directory structure)
# Files in Configs/newtool/.config/newtool/ → ~/.config/newtool/
# Files in Configs/newtool/ root → ~/ root

# Deploy the group
tuckr add newtool
```

### Creating Hooks

```bash
# Create hook script in Hooks/ directory (from your dotfiles repo root)
mkdir -p Hooks/newtool
vim Hooks/newtool/post.sh

# Make executable
chmod +x Hooks/newtool/post.sh

# Hook runs automatically when using `tuckr set newtool`
```

### Testing Changes

Since configurations are symlinked, changes are live immediately:

1. Edit config file (in Configs/ or via home directory symlink)
2. Changes take effect instantly
3. Commit changes to git when satisfied
4. For Nix changes, the `post_nix` hook rebuilds the system automatically

## Important Patterns

### Platform Detection

Groups with suffixes (`_macos`, `_linux`, `_windows`) only deploy on matching platforms. This prevents incompatible configs on multi-platform setups.

### Symlink Bootstrap

The `setup-tuckr-symlink.sh` script is crucial for initial setup:

1. Auto-detects the repo location from its own directory (or accepts a path argument)
2. Detects platform (macOS, Linux, BSD, Windows)
3. Creates platform-specific symlink (e.g., `~/Library/Application Support/dotfiles` → `<dotfiles-repo>`)
4. Handles existing symlinks and collision detection
5. Provides colored output for user feedback

### Hook Execution Flow

```
User runs: tuckr set <group>
    ↓
Pre-hook runs (if exists) - verify preconditions
    ↓
Tuckr creates symlinks
    ↓
Post-hook runs (if exists) - apply configurations, rebuild systems
    ↓
Complete
```

## File Naming Conventions

### Documentation Files

- **All documentation files must be lowercase**: Use `readme.md`, `changelog.md`, `license`, etc.
- **Never use capitalized names**: Do not use `README.md`, `CHANGELOG.md`, `LICENSE`
- This applies to all markdown files and documentation throughout the repository
- License files should be named `license` (no extension)

### Examples

- ✅ `readme.md` - Correct
- ❌ `README.md` - Wrong
- ✅ `license` - Correct
- ❌ `LICENSE` - Wrong

## Git Commit Conventions

All commits in this repository **must** follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Commit Message Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### Types

- **feat**: New feature for the user
- **fix**: Bug fix for the user
- **docs**: Documentation only changes
- **style**: Formatting, missing semicolons, etc. (no code change)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **build**: Changes to build system or dependencies
- **ci**: Changes to CI configuration
- **chore**: Other changes that don't modify src or test files
- **revert**: Reverts a previous commit

### Scopes

Use relevant scope based on what's being modified:

- **nix**: Nix configuration (darwin.nix, home.nix, flake.nix, custom packages)
- **nushell**: Nushell shell configuration
- **scripts**: Custom utility scripts
- **helix**: Helix editor configuration
- **tuckr**: Tuckr configuration or hooks
- **docs**: Documentation files (README, CLAUDE.md)
- **setup**: Setup scripts

### Examples

```
feat(nix): add pnpm-standalone custom package

- Create custom Nix derivation for pnpm without Node.js dependency
- Support macOS (arm64/x64) and Linux (arm64/x64)
- Add automated update script using nix-prefetch-url

fix(nix): disable stripping on macOS to prevent build crashes

The strip command crashes on standalone binaries on macOS.
Use dontStrip = stdenv.isDarwin to conditionally disable on macOS only.

docs(readme): add custom packages section

Document pnpm-standalone package and update workflow

feat(scripts): add update:pnpm:version utility

Automatically fetch latest pnpm version from GitHub and update
the Nix derivation with correct hash using nix-prefetch-url

chore(tuckr): add .tuckrignore files for autogenerated content

- Ignore nix build outputs (result, .devenv)
- Ignore home-manager symlinks
- Ignore helix runtime directory
```

### Breaking Changes

For breaking changes, add `!` after the type/scope:

```
feat(nix)!: remove deprecated nixfmt-rfc-style package

BREAKING CHANGE: nixfmt-rfc-style has been removed, use nixfmt instead
```

### Multi-line Commits

For significant changes, use the body to explain:

- What changed and why
- Any side effects or implications
- Migration steps if needed

### When Claude Code Makes Commits

When using Claude Code to make commits, ensure:

1. Commit messages follow this format
2. Type and scope are accurate
3. Subject is clear and concise (50 chars or less)
4. Body explains the "why" not just the "what"

## GitHub Workflow Conventions

All GitHub Actions workflow files **must** follow these naming and formatting conventions.

### Naming Rules

- **Workflow `name:` field**: always lowercase (e.g., `name: ci`, `name: claude code`)
- **Job names**: always lowercase, no emoji prefix (e.g., `name: lint & format (${{ matrix.os }})`)
- **Step names**: always lowercase, prefixed with a descriptive emoji (e.g., `name: 📥 checkout repository`)
- Every step **must** have a `name:` field — never use bare `uses:` or `run:` without a name

### Step Emoji Reference

| Emoji | Action              |
| ----- | ------------------- |
| 📥    | checkout            |
| 🔧    | install tools / nix |
| 📦    | install deps        |
| 🧪    | run tests           |
| 🔍    | linting / checking  |
| 🎨    | formatting          |
| 📝    | generate files      |
| 🏗️     | build               |
| 🤖    | AI / automation     |
| ✅    | verify / validate   |

## Nix Commands

- **Always** use `nix profile add`, **never** `nix profile install` (deprecated)

## Pre-Push Verification

**MANDATORY**: Before pushing any commits to the remote, always run the local CI checks to ensure they pass. At minimum:

1. **Format check**: `dprint check --config Configs/dprint/dprint.json`
2. **Shellcheck**: `shellcheck setup setup-tuckr-symlink.sh Hooks/*/post.sh`
3. **Nix flake check** (if nix files changed): Generate `machine.nix` if needed, then `nix flake check ./Configs/nix/.config/nix --impure --no-build`
4. **Local workflow test** (optional): `act -j lint-and-format` to run CI jobs locally via Docker

A convenience script is available: `nu Configs/scripts/.local/bin/ci_check`

If any check fails, fix the issues before pushing. Never push code that would fail CI.

### Local CI with `act`

[`act`](https://github.com/nektos/act) runs GitHub Actions workflows locally using Docker.

```bash
# List available jobs
act -l

# Run a specific job
act -j lint-and-format
act -j test
act -j setup-test

# Run all jobs (Linux runners only — macOS jobs are skipped)
act
```

**Limitations:**

- Only Linux (`ubuntu-*`) runners are supported; macOS jobs are skipped
- Requires Docker to be running
- Some GitHub-specific features (secrets, permissions) may not work locally

## Troubleshooting

### Symlink Conflicts

```bash
# Force overwrite existing files
tuckr add --force <group>
```

### Hook Not Running

```bash
# Ensure hooks are executable (from your dotfiles repo root)
chmod +x Hooks/*/post.sh
```

### Nix Flake Issues

```bash
# Rebuild system configuration (cross-platform)
rebuild

# Or use the hook
tuckr set nix
```

### Platform Mismatch

If a group won't deploy, check if it's platform-specific:

- Groups suffixed with `_macos` only deploy on macOS
- Groups suffixed with `_linux` only deploy on Linux

## Migration Notes

This repository was migrated from GNU Stow. Key differences:

| Feature          | GNU Stow           | Tuckr                     |
| ---------------- | ------------------ | ------------------------- |
| Structure        | Package root       | Configs/ subdirectory     |
| Ignore files     | `.stow-*-ignore`   | None (clean repo)         |
| Hooks            | Not supported      | Pre/post/rm hooks         |
| Platform support | Manual scripting   | Built-in suffix detection |
| Configuration    | Command-line flags | Convention-based          |

Migration artifacts are preserved in `.migration/` directory for reference but are not deployed.
