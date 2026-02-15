# Nix Darwin + Home Manager Configuration

This is a portable nix-darwin configuration with home-manager integration that uses a machine-specific configuration file (`machine.nix`) to manage per-machine settings.

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

3. **Create your machine configuration**:

   Auto-generate (recommended):
   ```bash
   generate-machine-config
   ```

   Or create manually:
   ```bash
   cd ~/.config/nix
   cp machine.nix.example machine.nix
   # Edit machine.nix with your username and system architecture
   ```

4. **Install nix-darwin** using this configuration:
   ```bash
   # First-time installation
   nix run nix-darwin -- switch --flake ~/.config/nix#default
   ```

5. **After first installation**, use the `rebuild` command:
   ```bash
   rebuild
   ```

   The `rebuild` command will auto-generate machine.nix if it doesn't exist.

   This will apply both your system configuration (darwin) and user configuration (home-manager) in one command!

### Common Commands

```bash
# Apply configuration changes (recommended)
rebuild

# Or use darwin-rebuild directly
sudo darwin-rebuild switch --flake ~/.config/nix#default

# Build without activating (test the configuration)
darwin-rebuild build --flake ~/.config/nix

# Check what would change without applying
darwin-rebuild build --flake ~/.config/nix && nix store diff-closures /run/current-system ./result

# List all generations
darwin-rebuild --list-generations

# Rollback to previous generation
sudo darwin-rebuild --rollback
```

### Rebuild Script

The `rebuild` command is a convenient wrapper that:

- Auto-generates `machine.nix` if it doesn't exist (using `generate-machine-config`)
- Displays your current configuration
- Increases file descriptor limits for Nix builds
- Runs darwin-rebuild with the correct flags
- Provides clear error messages

### Generate Machine Config Script

The `generate-machine-config` command auto-detects and creates `machine.nix`:

- Detects username from `$USER`
- Detects system architecture from `uname`
- Detects hostname from `scutil --get ComputerName` (macOS) or `hostname`
- Creates `~/.config/nix/machine.nix` with detected values
- Use `--force` to overwrite existing configuration
- Use `--output FILE` to write to a different location

**Note**: With the integrated home-manager setup, you only need to run `rebuild` - it will automatically apply both system and home-manager configurations together.

## Features

- **Machine-Specific Configuration**: Uses gitignored `machine.nix` for per-machine settings
- **No Impure Evaluation**: Pure flake evaluation with reliable configuration
- **Cross-Platform Home Manager**: User packages and settings in `home.nix` work on both macOS and Linux
- **Integrated Mode (macOS)**: Home-manager integrated with nix-darwin for one-command updates
- **Standalone Mode (Linux)**: Separate home-manager configurations for Linux systems
- **GUI Apps via nix-casks** (macOS only): Installs Homebrew casks as pure Nix derivations (no Homebrew process needed)
- **System Architecture Support**: Works with aarch64-darwin (Apple Silicon), x86_64-darwin (Intel), x86_64-linux, and aarch64-linux
- **Convenient Rebuild Script**: Simple `rebuild` command handles all the complexity

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

3. Create your machine configuration:

```bash
cd ~/.config/nix  # or wherever you cloned this repo
cp machine.nix.example machine.nix
# Edit machine.nix with your username and system architecture
```

4. Install nix-darwin:

```bash
nix run nix-darwin -- switch --flake ~/.config/nix
```

5. Use the rebuild command:

```bash
rebuild
```

### Linux Setup

3. Create your machine configuration:

```bash
cd ~/.config/nix
cp machine.nix.example machine.nix
# Edit machine.nix with your username and system (e.g., x86_64-linux)
```

4. Install home-manager standalone:

```bash
nix run nixpkgs#home-manager -- switch --flake ~/.config/nix#$(whoami)@x86_64-linux
```

### Machine Configuration

The `machine.nix` file contains your machine-specific settings:

```nix
{
  username = "yourusername";
  system = "aarch64-darwin";  # or "x86_64-darwin", "x86_64-linux", "aarch64-linux"
  hostname = "your-machine-name";  # optional, for documentation
}
```

This file is gitignored and never committed to the repository, making it safe to have different configurations on each machine

## Configuration Files

- **machine.nix**: Machine-specific configuration (gitignored)
  - Contains username, system architecture, and hostname
  - Created from `machine.nix.example` on each machine
  - Never committed to git
- **flake.nix**: Main flake configuration with inputs and outputs
  - Reads configuration from `machine.nix`
  - Exports `darwinConfigurations.default` for macOS
  - Exports `homeConfigurations` for standalone use
- **darwin.nix**: macOS system-level configuration (system settings, GUI apps via nix-casks, macOS-specific packages)
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
# Recommended: use the rebuild command
rebuild

# Or use darwin-rebuild directly
sudo darwin-rebuild switch --flake ~/.config/nix#default
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
  - GUI apps installed via nix-casks
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

**GUI apps via nix-casks** (macOS only):

GUI apps that were previously installed via Homebrew casks are now installed as pure Nix derivations using [nix-casks](https://github.com/atahanyorganci/nix-casks). No Homebrew installation is required.

To add a new GUI app:

1. **Check nix-casks first** — search for the Homebrew cask name at [nix-casks.atahan.dev](https://nix-casks.atahan.dev/). If available, add it to the cask list in `darwin.nix`:

   ```nix
   ++ (map (name: casks.${name}) [
     # ... existing casks ...
     "new-app-name"   # use exact Homebrew cask name
   ]);
   ```

2. **If not in nix-casks** — the app likely uses a `.pkg` installer. Create a custom derivation in `packages/`:

   - For `.dmg` containing `.app`: use `undmg` (see `packages/steam.nix`)
   - For `.dmg` containing `.pkg`: use `undmg` + `pkgutil` (see `packages/google-drive.nix`)
   - For direct `.pkg` download: use `pkgutil` (see `packages/zoom.nix`)

   Then add `callPackage` in the `let` block and append to `environment.systemPackages`.

3. **If in nixpkgs** — check `nix search nixpkgs <name>`. If available as a nixpkgs package, add it to `home.nix` instead (works cross-platform).

All custom app packages with rolling URLs have their hashes automatically refreshed during `rebuild`. Versioned packages check the Homebrew API for updates. Use `rebuild --skip-updates` to skip this step.

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
nix flake check ~/.config/nix

# Show flake outputs
nix flake show ~/.config/nix

# Rebuild system configuration (includes home-manager)
rebuild

# Or use darwin-rebuild directly
sudo darwin-rebuild switch --flake ~/.config/nix#default

# List generations
darwin-rebuild --list-generations

# Rollback
sudo darwin-rebuild --rollback
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

### "machine.nix not found" error

The `machine.nix` file is required but not tracked in git. Create it from the template:

```bash
cd ~/.config/nix
cp machine.nix.example machine.nix
# Edit with your username and system architecture
```

### "Failed to read username or system" error

Check that your `machine.nix` is properly formatted:

```nix
{
  username = "yourusername";  # Must be in quotes
  system = "aarch64-darwin";  # Must be in quotes
  hostname = "optional";
}
```

### Home Manager activation fails

Make sure home-manager is installed and integrated:

```bash
sudo darwin-rebuild switch --flake ~/.config/nix
```

## Migration from Old Setup

If you're migrating from a setup that used `--impure` or hardcoded usernames:

1. Pull the latest changes to this configuration
2. Create `machine.nix` from the example template
3. Edit `machine.nix` with your username and system
4. Run `rebuild` to apply the configuration
5. Your existing packages and settings will be preserved

## References

- [nix-darwin](https://github.com/LnL7/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [nix-casks](https://github.com/atahanyorganci/nix-casks)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
