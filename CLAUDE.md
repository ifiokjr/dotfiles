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
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash

# Remote installation (lite mode - CLI-focused)
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --lite

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
- `--no-confirm` - Run headlessly without interactive prompts
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

The repository contains 15 configuration groups organized in `Configs/`:

| Group       | Platform | Purpose                                         | Hook      |
| ----------- | -------- | ----------------------------------------------- | --------- |
| **nix**     | All      | System configuration with Nix flakes            | `post.sh` |
| **nushell** | All      | Nushell shell configuration & modules           | `post.sh` |
| **claude**  | All      | Claude Code settings & MCP server               | `post.sh` |
| **scripts** | All      | Custom utility scripts (~/.local/bin)           | None      |
| **shell**   | All      | Shared POSIX env (PATH, vars, secrets)          | None      |
| **bash**    | All      | Bash shell config sourcing shared env           | None      |
| **zsh**     | All      | Zsh shell config sourcing shared env            | None      |
| **helix**   | All      | Helix editor config & Steel plugins             | None      |
| **ghostty** | All      | Ghostty terminal emulator config                | None      |
| **zellij**  | All      | Terminal multiplexer config & layouts           | None      |
| **direnv**  | All      | Directory-specific environment variables        | None      |
| **dprint**  | All      | Multi-language code formatter                   | None      |
| **kdl**     | All      | KDL document formatter                          | None      |
| **lazygit** | All      | Git TUI configuration                           | None      |
| **yazi**    | All      | Yazi file manager with Helix/Zellij integration | None      |

**Platform-specific groups** (suffixed with `_macos`, `_linux`, etc.) only deploy on matching platforms.

**Deployment ordering:** The setup script deploys groups in explicit phases: `scripts` first (hooks depend on it), then `nix` (installs all tools), then simple groups (alphabetical), then late groups in order: `nushell` (needs starship/carapace from nix), `helix` (custom build needs nushell + cargo), `claude` (needs deno for MCP server).

## Architecture

### Directory Structure

```
<dotfiles-repo>/
├── Configs/                    # Configuration groups
│   ├── nix/                   # Nix system config (darwin + home-manager)
│   ├── nushell/               # Nushell shell config
│   ├── scripts/               # Custom utility scripts (~/.local/bin)
│   ├── shell/                 # Shared POSIX env (env.sh, .hushlogin)
│   ├── bash/                  # Bash shell config (.bashrc, .bash_profile)
│   ├── zsh/                   # Zsh shell config (.zshrc, .zprofile)
│   ├── claude/                # Claude Code settings & MCP server
│   ├── helix/                 # Helix editor config & Steel plugins
│   ├── ghostty/               # Ghostty terminal config
│   ├── zellij/                # Terminal multiplexer
│   ├── direnv/                # Environment management
│   ├── dprint/                # Code formatter
│   ├── kdl/                   # KDL formatter
│   ├── lazygit/               # Git TUI
│   └── yazi/                  # Yazi file manager config
├── Hooks/                      # Pre/post deployment scripts
│   ├── nix/post.sh            # Rebuilds system after Nix changes
│   ├── nushell/post.sh        # Generates vendor autoload, sets default shell
│   └── claude/post.sh         # Registers MCP server, caches Deno deps
├── setup                       # Automated setup script
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
3. **`Hooks/claude/post.sh`** - Registers tart-vm MCP server with Claude Code, caches Deno dependencies

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
- GUI apps via nix-casks (pure Nix derivations, no Homebrew needed)
- Integrated Home Manager (no separate invocation needed)

### Build Commands

```bash
# Primary method (on macOS)
darwin-rebuild switch --flake ~/.config/nix#default --impure

# Standalone Home Manager (Linux or standalone)
home-manager switch --flake ~/.config/nix#username@system --impure
# Example: home-manager switch --flake ~/.config/nix#ifiokjr@x86_64-linux --impure
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

This is **enforced in CI** by the `commit messages` job in `.github/workflows/ci.yml`. Pull requests with non-conventional commit subjects will fail checks.

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
- **claude**: Claude Code configuration
- **ci**: CI/CD workflows and configuration
- **tuckr**: Tuckr configuration or hooks
- **docs**: Documentation files (readme.md, CLAUDE.md)
- **setup**: Setup scripts

### Examples

```
feat(nix): add kubernetes-helm to home packages

Add kubernetes-helm to shared home-manager packages for macOS/Linux.

fix(scripts): make rebuild --update refresh flake.lock

Replace legacy package updater calls with nix flake update --flake.

docs(readme): document flake input update workflow

Describe rebuild --update behavior and external nixpkgs input usage.

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

### CI Integrity Rules

CI is split into two workflows:

- **`ci.yml`** — Fast checks that always run (~2-8 min): lint (ubuntu-only), test (both platforms). Lint tools are installed via `nix profile add` (not `./setup`).
- **`ci-nix.yml`** — Nix build validation that only runs when nix-related files change (~20-40 min): setup (both platforms), docker-integration (ubuntu-only).

Rules:

- **Never introduce workarounds for failing `./setup`** in `ci-nix.yml`. If `darwin-rebuild` or `home-manager switch` fails during the setup step, fix the root cause (broken packages, wrong config) instead of adding fallback `nix profile add` steps. Workarounds mask real build failures and defeat the purpose of CI.
- **All tools used in `ci-nix.yml` setup steps must come from the setup script**. The `./setup --skip-nix --no-confirm` step installs everything via `darwin-rebuild` (macOS) or `home-manager switch` (Linux). If a tool is missing after setup, it means the nix configuration is broken and must be fixed.
- **Lint tools in `ci.yml` are installed directly via `nix profile add`**. This avoids the slow `./setup` step for checks that don't need the full system configuration.
- **Packages marked as broken on a platform must be moved to platform-conditional lists**. Use `lib.optionals pkgs.stdenv.isLinux` or `lib.optionals pkgs.stdenv.isDarwin` in `home.nix`, or install via nix-casks in `darwin.nix` for macOS GUI apps.

## Nix Commands

- **Always** use `nix profile add`, **never** `nix profile install` (deprecated)

## Branching Workflow

All changes to `main` **must** be made via pull request. Direct pushes to `main` are not allowed (enforced by branch protection rules). The workflow is:

1. Create a feature branch from `main` (e.g., `fix/ci-failures`, `feat/new-tool`)
2. Make changes, commit, and push the branch
3. Open a pull request against `main`
4. Wait for CI to pass
5. Merge the pull request

Admins may bypass this rule in emergencies, but should prefer PRs whenever possible.

### Agent Workflow

When Claude Code (or other agents) starts a new feature or fix:

1. Fetch the latest `origin/main` before creating a branch
2. Create a branch following the naming convention (e.g., `fix/ci-failures`, `feat/new-tool`)
3. Keep the branch rebased on latest `main` throughout development
4. Enable `git rerere` for easier conflict resolution during repeated rebases:
   ```bash
   git config rerere.enabled true
   ```
5. Before pushing, run the pre-push verification checks (see below)
6. Open a pull request against `main`

**Worktree note:** If `git checkout main` fails because another worktree already has `main` checked out, use `origin/main` as the base instead (e.g., `git checkout -b feat/my-feature origin/main`).

## Pre-Push Verification

**MANDATORY**: Before pushing any commits to the remote, always run the local CI checks to ensure they pass. At minimum:

1. **Format check**: `dprint check --config Configs/dprint/dprint.json`
2. **Shellcheck**: `shellcheck setup setup-tuckr-symlink.sh Hooks/*/post.sh`
3. **Nix flake check** (if nix files changed): Generate `machine.nix` if needed, then `nix flake check ./Configs/nix/.config/nix --impure --no-build`
4. **Nix rebuild** (if nix packages changed): Run `rebuild` to verify all packages build and install correctly on the current platform
5. **Docker build** (if nix packages changed, verifies Linux): `docker build -t dotfiles-test .` to verify the configuration works on Linux
6. **Local workflow test** (optional): `act -j lint` or `act -j test` to run CI jobs locally via Docker

A convenience script is available: `nu Configs/scripts/.local/bin/ci_check`

If any check fails, fix the issues before pushing. Never push code that would fail CI.

**Package changes require extra verification**: When adding, removing, or updating packages in `home.nix` or `darwin.nix`, you **must** run `rebuild` locally to confirm the packages resolve and install. For cross-platform confidence, also run the Docker build to verify Linux compatibility. Never push package changes that have not been locally verified.

### Local CI with `act`

[`act`](https://github.com/nektos/act) runs GitHub Actions workflows locally using Docker.

```bash
# List available jobs
act -l

# Run ci.yml jobs (fast checks)
act -j lint
act -j test

# Run ci-nix.yml jobs (nix build validation)
act -j setup -W .github/workflows/ci-nix.yml
act -j docker-integration -W .github/workflows/ci-nix.yml

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
