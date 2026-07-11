# Open Questions (Contradictions To Resolve)

## 1) Manual Setup Order vs Documented Dependencies

**Decision:** Version B — deploy `nix` before `nushell`.

`nix` provides the runtime and package layer that `nushell` and other groups depend on. The `dot reload` command already orders `nix` in the primary bucket and `nushell` in the late bucket, and the setup script deploys `nix` early in the group list. Manual docs and recovery instructions should reflect this order.

## 2) `tuckr add nix` vs Hook-Based `tuckr set nix`

**Decision:** Version B — use `tuckr set nix`.

The `nix` group has a `post_up` hook (`Hooks/nix/post.sh`) that rebuilds the Nix configuration. Groups with hooks must use `tuckr set` so the hook runs. `dot reload` also classifies `nix` as a hook group. `Configs/nix/.config/nix/MACHINE_NIX_SETUP.md` has been updated to match.

## 3) Lowercase-Only Docs Rule vs Required Tooling Filenames

**Decision:** Version B — allow explicit exceptions for tool-required filenames.

The repository already uses `AGENTS.md` and other tooling-required names. The lowercase-only rule applies to project-authored documentation files; filenames mandated by external tools (e.g., `AGENTS.md`, `AGENT.md`) are exempt and should be listed explicitly.
