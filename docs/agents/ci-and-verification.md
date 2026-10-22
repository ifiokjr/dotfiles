# CI And Verification

## CI Workflows

- `.github/workflows/ci.yml`: fast checks, plus the `security-audit` job.
- `.github/workflows/ci-nix.yml`: Nix setup/build validation for Nix-related changes.
- `.github/workflows/update-nix.yml`: daily flake lock updates via PR.
- `.github/dependabot.yml`: weekly bumps for the SHA-pinned actions.

## Security Regression Suite

`tests/security-audit.sh` encodes every attack vector fixed in the 2026-10
security audit (plus invariants like "the firewall stays enabled" and "actions
stay SHA-pinned") as grep-able regression checks. It runs in CI and locally:

```bash
tests/security-audit.sh              # audit this checkout
tests/security-audit.sh --self-test  # inject each violation into a scratch
                                     # copy and prove the checks catch it
tests/security-audit.sh --list       # list check names
```

When you intentionally change one of the guarded behaviors (for example
re-enabling a bypassed permission mode on an expendable machine), update the
matching check and its `mutate_*` counterpart in the same PR so the self-test
stays green — a check that cannot fail is noise. Add new checks by following
the `reg`/`check_<name>`/optional `mutate_<name>` conventions in the script.

## Pre-Push Verification

Run before pushing relevant changes:

```bash
dprint check --config Configs/dprint/dprint.json
shellcheck setup setup-tuckr-symlink.sh Hooks/*/pre.sh Hooks/*/post.sh
tests/check-docs-consistency.sh
tests/security-audit.sh

# If nix files changed
nix flake check ./Configs/nix/.config/nix --impure --no-build

# If nix packages/config changed
dot rebuild
docker build -t dotfiles-test .

# Optional local workflow runs
act -j lint
act -j test
```

Convenience script:

```bash
nu Configs/scripts/.local/bin/ci_check
```
