# CI And Verification

## CI Workflows

- `.github/workflows/ci.yml`: fast checks.
- `.github/workflows/ci-nix.yml`: Nix setup/build validation for Nix-related changes.

## Pre-Push Verification

Run before pushing relevant changes:

```bash
dprint check --config Configs/dprint/dprint.json
shellcheck setup setup-tuckr-symlink.sh Hooks/*/post.sh

# If nix files changed
nix flake check ./Configs/nix/.config/nix --impure --no-build

# If nix packages/config changed
rebuild
docker build -t dotfiles-test .

# Optional local workflow runs
act -j lint
act -j test
```

Convenience script:

```bash
nu Configs/scripts/.local/bin/ci_check
```
