# Repository Architecture

## Structure

- `Configs/`: configuration groups.
- `Hooks/`: `pre.sh`, `post.sh`, and `rm.sh` scripts per group, plus optional `meta.sh` setup metadata.
- `setup`: automated bootstrap/deploy script.
- `setup-tuckr-symlink.sh`: creates platform-specific Tuckr symlink.
- `readme.md`: primary human documentation.

## Group Deployment Model

- Group files map to home paths through symlinks.
- `Configs/<group>/.config/<tool>/...` maps to `~/.config/<tool>/...`.
- `Configs/<group>/...` root files map to `~/...`.

## Ordering And Dependencies

- Tuckr remains the deployment engine:
  - `Configs/<group>/` defines the deployable group contents.
  - `Hooks/<group>/pre.sh|post.sh|rm.sh` define actual Tuckr hooks.
- `setup` now derives default deployment order from optional per-group metadata in `Hooks/<group>/meta.sh`:
  - human-readable descriptions
  - dependency ordering (for example `nix` depends on `scripts`, `helix` depends on `nushell`)
  - coarse phase hints such as `early` and `late`
- Platform-suffixed groups (for example `_macos`, `_linux`) deploy only on matching platforms, and metadata can further narrow platforms if needed.

## Active Hooks

- `Hooks/nix/post.sh`: rebuild system config after Nix deployment.
- `Hooks/nushell/post.sh`: generate vendor autoload and configure shell behavior.
- `Hooks/claude/post.sh`: register MCP server and cache Deno dependencies.
- `Hooks/pnpm/post.sh`: sync managed pnpm global manifests and install global packages.
- `Hooks/*/meta.sh`: setup-only metadata files used by dependency resolution and future onboarding features.
