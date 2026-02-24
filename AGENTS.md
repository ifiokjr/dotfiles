# AGENTS.md

This repository is a cross-platform, Tuckr-managed dotfiles repository that deploys config groups via symlinks/hooks, with Nix as the primary package/runtime layer.

## Essentials

- Package manager/runtime: `nix` (use `nix profile add`; avoid `nix profile install`).
- Non-standard verification commands:
  - `dprint check --config Configs/dprint/dprint.json`
  - `shellcheck setup setup-tuckr-symlink.sh Hooks/*/post.sh`
  - `nix flake check ./Configs/nix/.config/nix --impure --no-build` (when Nix files change)
  - `rebuild` (when Nix config or packages change)
  - `docker build -t dotfiles-test .` (when Nix config or packages change for Linux confidence)
- Git workflow requirements:
  - Use feature branches like `feat/*`, `fix/*`, `ci/*`, `chore/*` (no `codex/` prefix).
  - Use Conventional Commits.
  - Open a pull request to merge into `main`.

## Guides

- [Skills usage](docs/agents/skills.md)
- [Setup and deployment](docs/agents/setup-and-deployment.md)
- [Repository architecture](docs/agents/repository-architecture.md)
- [Nix and Nushell conventions](docs/agents/nix-and-nushell.md)
- [Git workflow](docs/agents/git-workflow.md)
- [CI and verification](docs/agents/ci-and-verification.md)
- [GitHub Actions conventions](docs/agents/github-actions.md)
- [Troubleshooting and migration](docs/agents/troubleshooting-and-migration.md)
- [Open contradictions](docs/agents/open-questions.md)
- [Prune candidates](docs/agents/prune-candidates.md)
