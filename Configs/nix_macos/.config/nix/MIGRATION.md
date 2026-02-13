# Migration to Machine-Specific Configuration

## What Changed

### Removed

- ❌ `--impure` flag requirement (pure flake evaluation now)
- ❌ yazelix home-manager integration (removed due to issues)
- ❌ Username-specific flake outputs (e.g., `darwinConfigurations.ifiokjr`)
- ❌ `rebuild` alias (now a proper script in ~/.local/bin)

### Added

- ✅ `machine.nix` - Machine-specific configuration file (gitignored)
- ✅ `machine.nix.example` - Template for new machines
- ✅ `generate-machine-config` - Auto-generates machine.nix
- ✅ `rebuild` - Smart rebuild script with auto-configuration
- ✅ Pure flake evaluation (no --impure needed)

## New Workflow

### First Time on a Machine

1. **Auto-generate configuration** (recommended):
   ```bash
   generate-machine-config
   ```

2. **Or create manually**:
   ```bash
   cd ~/.config/nix
   cp machine.nix.example machine.nix
   # Edit machine.nix if needed
   ```

3. **Rebuild**:
   ```bash
   rebuild
   ```

   Note: `rebuild` will auto-generate machine.nix if it doesn't exist!

### Regular Updates

Just run:

```bash
rebuild
```

No flags, no username, no --impure. It just works!

## Commands Available

### `rebuild`

- Auto-generates `machine.nix` if missing
- Shows current configuration before rebuilding
- Handles all darwin-rebuild complexity
- Increases file descriptor limits automatically

```bash
rebuild                # Rebuild system
rebuild --skip-check   # Skip flake check
rebuild --help         # Show help
```

### `generate-machine-config`

- Auto-detects username, system, hostname
- Creates ~/.config/nix/machine.nix

```bash
generate-machine-config          # Create machine.nix
generate-machine-config --force  # Overwrite existing
generate-machine-config --output custom.nix  # Custom location
```

## Flake Structure

```nix
{
  darwinConfigurations.default = {
    # Reads from ~/.config/nix/machine.nix (deployed location)
    username = "ifiokjr";
    system = "aarch64-darwin";
  };

  homeConfigurations."ifiokjr@aarch64-darwin" = {
    # For standalone home-manager (Linux)
  };
}
```

## Important: machine.nix Location

The flake reads `machine.nix` from `~/.config/nix/machine.nix` (the deployed location), NOT from the dotfiles repo. This ensures:

- Each machine has its own configuration
- Changes take effect immediately after running `generate-machine-config`
- No need to manually sync between dotfiles and deployed location

## Machine.nix Format

```nix
{
  username = "yourusername";
  system = "aarch64-darwin";  # or x86_64-darwin, x86_64-linux, aarch64-linux
  hostname = "your-machine-name";  # Optional
}
```

## Testing the Migration

1. **Check machine.nix exists**:
   ```bash
   cat ~/.config/nix/machine.nix
   ```

2. **Verify flake**:
   ```bash
   cd ~/.config/nix
   nix flake show
   ```

3. **Test rebuild** (dry-run):
   ```bash
   darwin-rebuild build --flake ~/.config/nix
   ```

4. **Apply changes**:
   ```bash
   rebuild
   ```

## Troubleshooting

### "machine.nix not found"

Run: `generate-machine-config`

### "Permission denied on flake.lock"

The flake.lock was created by root. Fix:

```bash
sudo rm ~/.config/nix/flake.lock
cd ~/.config/nix && nix flake lock
```

### "Configuration 'bring-the-heat-yo' not found"

This is your old system configuration. The new flake uses `default` instead. Just run `rebuild` - it will switch to the new configuration.

### "darwinConfigurations.USERNAME.system not found"

Darwin-rebuild auto-appends your username when no config is specified. The `rebuild` script now explicitly uses `#default`:

```bash
sudo darwin-rebuild switch --flake ~/.config/nix#default
```

## Benefits

1. **No --impure flag** - Pure evaluation is faster and more reliable
2. **No hardcoded usernames** - Works on any machine after running generate-machine-config
3. **Gitignored machine.nix** - Each machine has its own config without conflicts
4. **Simpler workflow** - Just run `rebuild`
5. **Better error messages** - Clear instructions when something goes wrong
