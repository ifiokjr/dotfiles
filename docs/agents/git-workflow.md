# Git Workflow

## Branching

- Create a feature branch from latest `origin/main`.
- Use names like `feat/*`, `fix/*`, `ci/*`, `chore/*`.
- Do not use `codex/` prefix.
- When work splits into related, dependent changes, default to a stack of PRs (see [Stacked Pull Requests](#stacked-pull-requests)).
- Merge to `main` via pull request.
- Use squash merge only.

## Merge Strategy

- `squash` is the only allowed merge method.
- Do not use merge commits.
- Do not use rebase merges.

## Stacked Pull Requests

- Default to a stack of small PRs when related changes depend on each other; avoid one giant PR and avoid rebasing a long-lived branch onto `main` after every merge.
- Requires the official extension: `gh extension install github/gh-stack`.
- Flow: `gh stack init`, `gh stack add -Am "<commit>"`, `gh stack submit --auto` (push + open linked PRs), `gh stack sync` (cascade-rebase), `gh stack merge --yes --squash`.
- Keep `squash` as the merge method (`gh stack merge --squash`).
- When a lower layer merges, GitHub automatically rebases and retargets the PRs above it.
- Stacked PRs are in public preview: all branches must be in the same repository (no forks), and merge queue support is still rolling out.
- Clean history per layer before `gh stack submit`, with no `wip:` commits.

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

## Media Attachments

Never commit screenshots, videos, GIFs, design mocks, traces, datasets, or other binary assets to the repository. Git keeps every version forever, so the repository only grows and clones and CI get slower; a later delete commit does not shrink the history. Link the asset instead.

- Only small runtime brand assets belong in the repository: logos, favicons, app icons, and social previews. Optimize them, and link anything the project does not need to build, run, or render.
- Publish README and docs images one of two ways:
  1. **Backblaze B2**: upload with the `backblaze-upload` skill, then link the public URL in the Markdown file.
  2. **GitHub attachment**: attach with `gh ... --attach` to one pinned `Media assets` issue per repository (or to the PR when the image is review proof), then copy the uploaded URL into the Markdown file.
- Videos follow the same rule: link the B2 object, or attach the video to a PR or issue for review. Never commit the video file.
- Git LFS is not an exception unless the user explicitly asks for it.
- If media is already tracked, stop and ask before rewriting history.
- `gh 2.99.0+` supports `--attach` on `gh pr create/edit/comment` and `gh issue create/edit/comment`; repeat the flag for multiple files and add alt text as `./file.png#Alt text`.
- Never attach secrets or personal images: no tokens, API keys, `.env` contents, terminal output showing secret material (e.g. `msr`/`msload`/1Password output), SSH keys, or private/personal photos. Uploads land on GitHub's CDN where anyone with the URL can view them and they cannot be reliably deleted.
- Redact or crop screenshots before attaching when anything sensitive is visible; if in doubt, describe it in text instead.
