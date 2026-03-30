# Repository Architecture

## Structure

- `Configs/`: configuration groups plus sidecar `*.group.toml` metadata files.
- `Hooks/`: `pre.sh`, `post.sh`, and `rm.sh` scripts per group.
- `lib/setup/`: reusable setup helpers for metadata resolution, deployment orchestration, and doctor checks.
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
- `setup` now derives orchestration from per-group metadata in `Configs/<group>.group.toml`:
  - human-readable descriptions
  - preset membership (`core`, `dev`, `workstation`, `ci`)
  - dependency ordering (for example `nix` depends on `scripts`, `helix` depends on `nushell`)
- Platform-suffixed groups (for example `_macos`, `_linux`) still deploy only on matching platforms, and metadata can further narrow platforms if needed.

## Active Hooks

- `Hooks/nix/post.sh`: rebuild system config after Nix deployment.
- `Hooks/nushell/post.sh`: generate vendor autoload and configure shell behavior.
- `Hooks/claude/post.sh`: register MCP server and cache Deno dependencies.
- `Hooks/pnpm/post.sh`: sync managed pnpm global manifests and install global packages.
- `Configs/*.group.toml`: setup-only metadata files parsed by Nushell during preset selection and dependency resolution.
