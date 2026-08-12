# Open Questions (Contradictions To Resolve)

## 1) Manual Setup Order vs Documented Dependencies

**Decision:** Version B — deploy `nix` before `nushell`.

`nix` provides the runtime and package layer that `nushell` and other groups depend on. The `dot reload` command already orders `nix` in the primary bucket and `nushell` in the late bucket, and the setup script deploys `nix` early in the group list. Manual docs and recovery instructions should reflect this order.

## 2) `tuckr add nix` vs Hook-Based `tuckr set nix`

**Decision:** Use `tuckr set nix` for setup or an explicit Nix deployment, and `tuckr add --only-files nix` during reloads.

The `nix` group has a `post_up` hook (`Hooks/nix/post.sh`) that rebuilds the Nix configuration. Setup intentionally runs that hook. In contrast, `dot reload` and `tuckr:reload` are symlink-only operations: they use `tuckr add --only-files nix` so a reload only reconciles Nix symlinks and cannot rebuild packages or modify the tracked `Configs/nix/.config/nix/flake.lock`. Use `dot rebuild` when package activation is intended.

## 3) Lowercase-Only Docs Rule vs Required Tooling Filenames

**Decision:** Version B — allow explicit exceptions for tool-required filenames.

The repository already uses `AGENTS.md` and other tooling-required names. The lowercase-only rule applies to project-authored documentation files; filenames mandated by external tools (e.g., `AGENTS.md`, `AGENT.md`) are exempt and should be listed explicitly.
