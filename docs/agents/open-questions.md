# Open Questions (Contradictions To Resolve)

## 1) Manual Setup Order vs Documented Dependencies

- Version A: manual setup currently shows `tuckr set nushell` before `nix`.
- Version B: deployment docs and setup script indicate `nix` should be deployed before `nushell`.

Decision needed: keep A or B.

## 2) `tuckr add nix` vs Hook-Based `tuckr set nix`

- Version A: manual setup uses `tuckr add nix`.
- Version B: hook guidance says groups with hooks (including `nix`) should use `tuckr set`.

Decision needed: keep A or B.

## 3) Lowercase-Only Docs Rule vs Required Tooling Filenames

- Version A: all docs must be lowercase with no capitalized markdown filenames.
- Version B: allow explicit exceptions for tool-required names like `AGENTS.md`, `AGENT.md`, and `CLAUDE.md`.

Decision needed: keep A or B.
