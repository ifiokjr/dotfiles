# Troubleshooting And Migration

## Troubleshooting

```bash
# Overwrite conflicting files during deploy
tuckr add --force <group>

# Ensure hooks are executable
chmod +x Hooks/*/post.sh

# Rebuild Nix config
rebuild
# or
tuckr set nix
```

If a platform-specific group does not deploy, confirm the group suffix matches the current OS.

## Migration Notes

This repo migrated from GNU Stow to Tuckr.

- Package layout moved to `Configs/`.
- Hook support is now native (`pre`/`post`/`rm`).
- Platform-aware group suffixes are built in.
- Historical migration artifacts are in `.migration/` and are not deployed.
