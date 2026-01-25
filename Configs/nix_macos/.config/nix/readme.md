# Nix Darwin + Home Manager Configuration

This is a portable nix-darwin configuration with home-manager integration that can be used across multiple macOS systems without hardcoding usernames or system-specific paths.

## Getting Started with Darwin Rebuild

If you're new to nix-darwin, here's what you need to know:

### What is darwin-rebuild?

`darwin-rebuild` is the main command for managing your macOS system configuration with nix-darwin. It's similar to `nixos-rebuild` on NixOS, but designed specifically for macOS.

### First Time Setup

1. **Install Nix** (if not already installed):
   ```bash
   sh <(curl -L https://nixos.org/nix/install)
   ```

2. **Enable flakes** in `~/.config/nix/nix.conf`:
   ```
   experimental-features = nix-command flakes
   ```

3. **Install nix-darwin** using this configuration:
   ```bash
   # Clone or navigate to this configuration directory
   cd ~/.config/nix  # or wherever you have this config

   # First-time installation
   nix run nix-darwin -- switch --flake .#$(whoami)
   ```

4. **After first installation**, use `darwin-rebuild` directly:
   ```bash
   sudo darwin-rebuild switch --flake ~/.config/nix#$(whoami)
   ```

   This will apply both your system configuration (darwin) and user configuration (home-manager) in one command!

### Common Darwin Rebuild Commands

```bash
# Apply configuration changes
sudo darwin-rebuild switch --flake ~/.config/nix#$(whoami)

# Build without activating (test the configuration)
darwin-rebuild build --flake ~/.config/nix#$(whoami)

# Check what would change without applying
darwin-rebuild build --flake ~/.config/nix#$(whoami) && nix store diff-closures /run/current-system ./result

# List all generations
darwin-rebuild --list-generations

# Rollback to previous generation
sudo darwin-rebuild --rollback
```

### Recommended Aliases

Add these to your `~/.zshrc` or `~/.bashrc` for convenience:

```bash
alias update="sudo zsh -c \"nix flake update --flake \$HOME/.config/nix\""
alias rebuild="sudo zsh -c \"darwin-rebuild switch --flake \$HOME/.config/nix#\$(whoami)\""
```

Then you can simply run `rebuild` to apply your configuration changes!

**Note**: With the integrated home-manager setup, you only need to run `darwin-rebuild` - it will automatically apply both system and home-manager configurations together.

## Features

- **Dynamic User Detection**: Automatically detects the current user with `--impure` flag
- **Pure Flake Support**: Can also work in pure mode with a default configuration
- **Cross-Platform Home Manager**: User packages and settings in `home.nix` work on both macOS and Linux
- **Integrated Mode (macOS)**: Home-manager integrated with nix-darwin for one-command updates
- **Standalone Mode (Linux)**: Separate home-manager configurations for Linux systems
- **Homebrew Integration** (macOS only): Uses nix-homebrew for declarative Homebrew management
- **System Architecture Detection**: Supports aarch64-darwin, x86_64-darwin, x86_64-linux, and aarch64-linux

## Quick Start on a New System

### Prerequisites

1. Install Nix with flakes enabled:
```bash
sh <(curl -L https://nixos.org/nix/install)
```

2. Enable flakes in `~/.config/nix/nix.conf`:
```
experimental-features = nix-command flakes
```

### macOS Setup

3. Install nix-darwin:
```bash
nix run nix-darwin -- switch --flake /path/to/this/directory#
```

### Linux Setup

3. Install home-manager standalone:
```bash
# No additional system setup needed, just use home-manager directly
# See "Initial Setup" below for Linux-specific commands
```

### Initial Setup

#### macOS - Method 1: Using the Helper Script (Easiest)

The repository includes an `apply.sh` helper script that simplifies the process:

```bash
# Navigate to this directory
cd ~/.config/nix  # or wherever you cloned this repo

# Apply both darwin and home-manager configurations
./apply.sh

# See all options
./apply.sh --help
```

#### macOS - Method 2: Auto-detect Current User (Manual)

This method automatically detects your username using the `--impure` flag:

```bash
# Navigate to this directory
cd ~/.config/nix  # or wherever you cloned this repo

# Apply darwin configuration (includes home-manager)
darwin-rebuild switch --flake .# --impure
```

#### Linux - Standalone Home Manager

For Linux systems, use home-manager standalone:

```bash
# Navigate to this directory
cd ~/.config/nix  # or wherever you cloned this repo

# Apply home-manager configuration
# Format: username@system
home-manager switch --flake .#$(whoami)@x86_64-linux

# For ARM Linux (e.g., Raspberry Pi, ARM servers)
home-manager switch --flake .#$(whoami)@aarch64-linux

# Or with auto-detection (impure mode)
home-manager switch --flake .#$(whoami)@$(nix eval --impure --raw --expr 'builtins.currentSystem')
```

#### Method 3: Pure Flake with Default Configuration

If you want to use pure evaluation (without `--impure`), you can use the default configuration:

```bash
# This uses the "default" configuration name
darwin-rebuild switch --flake .#default

# For home-manager
nix run nixpkgs#home-manager -- switch --flake .#default
```

#### Method 4: Create a Named Configuration

For pure evaluation with your specific username, edit `flake.nix` and add your configuration:

```nix
# In the outputs section, add:
homeConfigurations.yourusername = mkHomeConfig "yourusername";
darwinConfigurations.yourusername = mkDarwinConfig "yourusername";
```

Then apply it:

```bash
darwin-rebuild switch --flake .#yourusername
nix run nixpkgs#home-manager -- switch --flake .#yourusername
```

## Configuration Files

- **flake.nix**: Main flake configuration with inputs and outputs
  - Exports `darwinConfigurations` for macOS (with integrated home-manager)
  - Exports `homeConfigurations` for standalone use (Linux or macOS)
- **darwin.nix**: macOS system-level configuration (system settings, homebrew, macOS-specific packages)
- **home.nix**: User-level home-manager configuration (CLI tools, development packages, shell config)
  - Works on both macOS and Linux
  - Most packages are managed here for cross-platform compatibility

## Updating

### Update Flake Inputs

```bash
nix flake update
```

### Apply Updates

```bash
# With auto-detection
darwin-rebuild switch --flake .# --impure

# Or with specific configuration
darwin-rebuild switch --flake .#yourusername
```

## Architecture

### Dual-Mode Design

This configuration supports two deployment modes:

#### 1. Integrated Mode (macOS)
- nix-darwin manages both system-level and user-level configurations
- home-manager is integrated as a nix-darwin module
- Running `darwin-rebuild` applies both system and home configurations together
- Recommended for macOS systems

#### 2. Standalone Mode (Linux or macOS)
- home-manager runs independently
- Only user-level packages and configurations are managed
- Ideal for Linux systems or macOS systems without nix-darwin
- Use `home-manager switch` to apply configurations

### Package Organization

- **home.nix**: Contains 90% of packages - all CLI tools, development packages, and user settings
  - Works identically on macOS and Linux
  - Includes cross-platform environment variables
  - Manages shell configurations (zsh, bash, fish)

- **darwin.nix**: Contains macOS-specific system configuration
  - Homebrew packages and casks
  - System preferences (dock, keyboard, etc.)
  - macOS-only system packages that need system integration
  - nix-darwin settings

This organization maximizes portability while keeping macOS system management clean.

## Customization

### Adding Packages

**User packages** (recommended - works on macOS and Linux):
- Edit `home.nix`
- Add to `home.packages`
- These packages work on both macOS and Linux

**System packages** (macOS only, requires system integration):
- Edit `darwin.nix`
- Add to `environment.systemPackages`
- Only for packages that need system-level integration

**Homebrew packages** (macOS only):
- Edit `darwin.nix`
- Add to `homebrew.brews` or `homebrew.casks`
- For macOS GUI apps and tools not available in nixpkgs

### Environment Variables

**User-specific** (recommended - cross-platform):
- Edit `home.nix`
- Add to `home.sessionVariables`
- Works on both macOS and Linux

### Shell Configuration

**Zsh, Bash, Fish** (cross-platform):
- Edit `home.nix`
- Configure under `programs.zsh`, `programs.bash`, or `programs.fish`
- Works on both macOS and Linux

## Common Commands

### macOS

```bash
# Check flake syntax
nix flake check

# Show flake outputs
nix flake show

# Rebuild system configuration (includes home-manager)
darwin-rebuild switch --flake .#$(whoami)

# List generations
darwin-rebuild --list-generations

# Rollback
darwin-rebuild --rollback
```

### Linux

```bash
# Check flake syntax
nix flake check

# Show flake outputs
nix flake show

# Rebuild home configuration
home-manager switch --flake .#$(whoami)@x86_64-linux

# List generations
home-manager generations

# Rollback
home-manager --rollback
```

## Troubleshooting

### "User not found" or incorrect username

Make sure you're using the `--impure` flag if relying on auto-detection:
```bash
darwin-rebuild switch --flake .# --impure
```

### Home Manager activation fails

Make sure home-manager is installed:
```bash
nix run nixpkgs#home-manager -- switch --flake .# --impure
```

### Homebrew packages not installing

Make sure you've run `darwin-rebuild` at least once, which sets up nix-homebrew integration.

## Migration from Old Setup

If you're migrating from a setup with hardcoded usernames:

1. Pull the latest changes to this configuration
2. Run `nix flake check` to verify syntax
3. Apply with `darwin-rebuild switch --flake .# --impure`
4. Your existing packages and settings will be preserved

## References

- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [nix-homebrew](https://github.com/zhaofengli/nix-homebrew)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
