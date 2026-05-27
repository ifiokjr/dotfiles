# Git Workflow

## Branching

- Create a feature branch from latest `origin/main`.
- Use names like `feat/*`, `fix/*`, `ci/*`, `chore/*`.
- Do not use `codex/` prefix.
- Merge to `main` via pull request.
- Use squash merge only.

## Merge Strategy

- `squash` is the only allowed merge method.
- Do not use merge commits.
- Do not use rebase merges.

## Agent Branch Flow

1. `git fetch origin main`
2. Create branch from `origin/main`
3. Keep branch rebased on latest `main`
4. Optionally enable `git rerere` for repeated conflict resolution
5. Run verification checks before push
6. Push branch and open PR

## Commit Conventions

Use Conventional Commits:

```text
<type>(<scope>): <subject>
```

Common scopes in this repo:

- `nix`, `nushell`, `scripts`, `helix`, `ci`, `tuckr`, `docs`, `setup`
