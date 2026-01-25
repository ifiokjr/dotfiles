# Helix Runtime Symlink

The original helix configuration had a symlink to a custom helix runtime:

```bash
runtime -> /Users/ifiokjr/Developer/os/helix/runtime
```

This symlink was **not copied** to the dotfiles repo as it points to a user-specific location.

## Automatic Setup with install:helix:custom

If you're using the `install:helix:custom` script, the runtime symlink is **automatically created** for you. The script will:

1. Build the custom helix at `~/.custom-helix`
2. Create a symlink: `~/.config/helix/runtime -> ~/.custom-helix/runtime`
3. Overwrite any existing runtime symlink or directory

No manual action is needed when using the install script.

## Manual Setup (Alternative Builds)

If you're using a different custom helix build (not from `install:helix:custom`), you can manually create the symlink:

```bash
ln -sf ~/Developer/os/helix/runtime ~/.config/helix/runtime
```

Or adjust the path to wherever your custom helix runtime is located.
