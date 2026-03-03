# Repository Architecture

## Structure

- `Configs/`: configuration groups.
- `Hooks/`: `pre.sh`, `post.sh`, and `rm.sh` scripts per group.
- `setup`: automated bootstrap/deploy script.
- `setup-tuckr-symlink.sh`: creates platform-specific Tuckr symlink.
- `readme.md`: primary human documentation.

## Group Deployment Model

- Group files map to home paths through symlinks.
- `Configs/<group>/.config/<tool>/...` maps to `~/.config/<tool>/...`.
- `Configs/<group>/...` root files map to `~/...`.

## Ordering And Dependencies

- Setup script deploy order is explicit:
  1. `scripts`
  2. `nix`
  3. simple groups (alphabetical)
  4. `nushell`, `helix`, `claude`
- Platform-suffixed groups (for example `_macos`, `_linux`) deploy only on matching platforms.

## Active Hooks

- `Hooks/nix/post.sh`: rebuild system config after Nix deployment.
- `Hooks/nushell/post.sh`: generate vendor autoload and configure shell behavior.
- `Hooks/claude/post.sh`: register MCP server and cache Deno dependencies.
- `Hooks/pnpm/post.sh`: sync managed pnpm global manifests and install global packages.
