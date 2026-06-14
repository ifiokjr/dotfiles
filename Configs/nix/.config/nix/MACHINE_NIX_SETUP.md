# machine.nix Setup and Usage

## Overview

`machine.nix` is a gitignored, machine-specific configuration file that stores settings unique to each machine:

- Username
- System architecture (aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux)
- Hostname (for documentation)
- Optional lite profile flag (CLI-focused install)

## File Locations

### Deployed Location (Used by Flake)

- **Path**: `~/.config/nix/machine.nix`
- **Purpose**: The flake reads from this location
- **Created by**: `generate-machine-config` script or Tuckr post_up hook
- **Managed by**: Tuckr symlinks OR direct file

### Dotfiles Repository (Template)

- **Path**: `Configs/nix/.config/nix/machine.nix.example`
- **Purpose**: Template for new machines
- **Status**: Tracked in git, copied/symlinked by Tuckr

## How It Works

### 1. Flake Evaluation

```nix
# flake.nix reads from deployed location
homeDir = builtins.getEnv "HOME";
machineConfigPath = "${homeDir}/.config/nix/machine.nix";
```

The flake always reads from `$HOME/.config/nix/machine.nix`, regardless of where the flake itself is evaluated from.

### 2. File Creation

When you run `dot rebuild` or `generate-machine-config` for the first time:

1. Script checks if `~/.config/nix/machine.nix` exists
2. If not, auto-generates with detected values:
   - Username from `$USER`
   - System from `uname -m` and `$OSTYPE`
   - Hostname from `scutil --get ComputerName` (macOS) or `hostname`

### 3. Tuckr Integration

The `post_up_nix` hook ensures `machine.nix` exists after deployment:

- Runs after Tuckr deploys nix group
- Creates machine.nix if missing
- Uses `generate-machine-config` if available

## Usage

### Create machine.nix (First Time)

**Auto-generate (recommended)**:

```bash
generate-machine-config
```

**Manual creation**:

```bash
cp ~/.config/nix/machine.nix.example ~/.config/nix/machine.nix
# Edit with your settings
```

### Update Configuration

1. **Edit machine.nix**:
   ```bash
   nano ~/.config/nix/machine.nix
   # or
   vim ~/.config/nix/machine.nix
   ```

2. **Rebuild**:
   ```bash
   dot rebuild
   ```

Changes take effect immediately - no need to sync files.

### On a New Machine

1. Clone dotfiles and deploy with Tuckr:
   ```bash
   tuckr set nix
   ```

2. The `post_up_nix` hook will create machine.nix automatically

3. Or run manually:
   ```bash
   generate-machine-config
   ```

4. Rebuild:
   ```bash
   dot rebuild
   ```

## Format

```nix
{
  # Your username on this machine
  username = "yourusername";

  # System architecture
  system = "aarch64-darwin";  # or x86_64-darwin, x86_64-linux, aarch64-linux

  # Machine hostname (optional, for documentation)
  hostname = "your-machine-name";

  # Lite profile (optional, CLI-focused install)
  # Set to true to skip GUI-heavy applications
  lite = false;
}
```

## Why This Approach?

### Advantages

1. **Per-machine configuration**: Each machine has its own settings
2. **No git conflicts**: File is gitignored, never committed
3. **Works with Tuckr**: Deploys alongside other nix configs
4. **Pure evaluation**: Flake reads from fixed location, no --impure needed
5. **Auto-detection**: Scripts detect correct values automatically

### Alternative Approaches Considered

- **--impure flag**: Unreliable, doesn't work consistently
- **Hardcoded usernames**: Doesn't work across machines
- **Environment variables**: Not available during pure evaluation
- **Per-user flake outputs**: Requires updating flake.nix for each user

## Troubleshooting

### "machine.nix not found"

Run: `generate-machine-config`

### Wrong username/system detected

Edit manually: `nano ~/.config/nix/machine.nix`

### Changes not taking effect

1. Verify file exists: `cat ~/.config/nix/machine.nix`
2. Check flake reads it: `nix eval ~/.config/nix#darwinConfigurations --apply 'x: builtins.attrNames x'`
3. Rebuild: `dot rebuild`

### File is a symlink vs real file

Both work! Tuckr may create a symlink if the file exists in the repo, or it may be a real file created by `generate-machine-config`. The flake reads from the deployed location either way.

## Scripts

### `generate-machine-config`

- Auto-detects username, system, hostname
- Creates `~/.config/nix/machine.nix`
- Use `--force` to overwrite
- Use `--output FILE` for custom location

### `dot rebuild`

- Checks for machine.nix, creates if missing
- Shows current configuration
- Rebuilds darwin/home-manager
- Use `--skip-check` to skip flake check

### `post_up_nix` (Hook)

- Runs after Tuckr deployment
- Ensures machine.nix exists
- Auto-generates if missing

## Lite Setup

- Run `./setup --lite` to automatically set `lite = true` in `machine.nix`
- Run `dot rebuild --lite` to set `lite = true` as the persisted default
- Run `dot rebuild --no-lite` to set `lite = false` as the persisted default
- Lite mode keeps CLI tooling and skips GUI-heavy applications in nix configs
