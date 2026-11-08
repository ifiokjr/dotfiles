# Troubleshooting And Migration

## Troubleshooting

```bash
# Overwrite conflicting files during deploy
tuckr add --force <group>

# Ensure hooks are executable
chmod +x Hooks/*/pre.sh Hooks/*/post.sh

# Rebuild Nix config
dot rebuild
# or
tuckr set nix
```

If a platform-specific group does not deploy, confirm the group suffix matches the current OS.

## Rebuild log

Every `dot rebuild` appends its full stdout and stderr to `~/.local/state/dotfiles/rebuild.log`, success or failure. Each run is delimited by a `=== dot rebuild … ===` header and an `=== exit N … (duration) ===` footer, so the latest session is the text between the last header and the last footer. The file is capped at 10 MB: once it grows past the cap, the oldest lines are dropped and roughly the newest 8 MB are kept.

Inspect it when a rebuild failed or printed warnings after the terminal is gone (for example after an unattended SSH rebuild):

```bash
# Show the most recent session
awk '/^=== dot rebuild /{buf=""} {buf = buf $0 ORS} END{printf "%s", buf}' ~/.local/state/dotfiles/rebuild.log
```

The launchd fleet flow writes the same file, so unattended and interactive rebuilds share one history.

## Migration Notes

This repo migrated from GNU Stow to Tuckr.

- Package layout moved to `Configs/`.
- Hook support is now native (`pre`/`post`/`rm`).
- Platform-aware group suffixes are built in.
- Historical migration artifacts are in `.migration/` and are not deployed.
