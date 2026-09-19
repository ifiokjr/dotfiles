---
name: github
description: Recent GitHub features that model training data misses, led by native stacked pull requests and file and video attachments through the gh CLI. Use whenever the user mentions GitHub, gh, the GitHub CLI, pull requests, issues, stacked PRs or stacked commits, uploading screenshots or videos to a PR or issue, GitHub Actions, rulesets, secret scanning, Dependabot, Copilot, or GitHub Apps and tokens. Load this before assuming a GitHub workflow is unavailable, and before writing any command that uses gh.
---

# GitHub features your training data is missing

GitHub ships faster than any model's training cutoff, so an agent that trusts its memory reaches for workflows that are either obsolete or needlessly manual. This skill is the inventory of what exists now, so you default to the current path instead of the one you remember.

The two features that matter most, because they replace multi-step manual work:

1. **Stacked pull requests are native.** Ship dependent changes as a chain of small PRs instead of one giant PR or a branch you rebase by hand.
2. **`gh` uploads attachments.** Screenshots and videos go into PRs, issues, and comments straight from the CLI, with no browser round trip.

Everything else is in the sections that follow. Check the reference file for the long tail before telling a user something is not possible.

## Stacked pull requests

A stack is an ordered chain of PRs where each one targets the layer below it. Reviewers see only that layer's diff, and merging a lower layer automatically rebases and retargets the PRs above it. Stacks are native to GitHub: required checks, reviews, and branch protections still apply.

**Status:** public preview since July 30, 2026, rolling out to all repositories. No opt-in flag. Merge queue support rolled out progressively after launch.

**Install the extension once per machine:**

```bash
gh extension install github/gh-stack
gh skill install github/gh-stack    # optional: teach coding agents the workflow
gh stack alias                      # optional: installs a `gs` wrapper
```

**The flow:**

```bash
gh stack init                              # start a stack from the trunk
gh stack add -Am "feat(scope): layer one"  # commit and create the next layer
gh stack add -Am "feat(scope): layer two"
gh stack submit --auto                     # push branches and open the linked PRs
gh stack sync                              # fetch, cascade-rebase, push, reconcile PR state
gh stack merge --yes --squash              # land the stack with squash merges
```

**What you need to know before using it:**

- Merging the top ready PR lands it and every unmerged layer below it in one operation. Merging a lower layer leaves the upper PRs open, rebased and retargeted automatically.
- Merge is all or nothing for the selected range. If any PR cannot merge, none of them do.
- Bypassing merge requirements is not supported for stacked merges. Branch protection is evaluated at merge time, and only basic state (open, not a draft) is pre-checked.
- When the base branch uses a merge queue, the whole stack is queued instead of merged directly. The queue picks the merge method, so any `--merge`, `--squash`, or `--rebase` flag is ignored with a warning, and PRs may land in separate groups.
- All branches in a stack must live in the same repository. Fork stacks are not supported.
- `gh stack push` is not atomic and does not create or update PRs. `gh stack sync` also never opens PRs; use `gh stack submit` for that.
- `gh stack modify` opens an interactive TUI. Avoid it in agent runs unless the user asks for it.
- Stacks land as squash merges in this repo. Use `gh stack merge --squash`.

Useful companions: `gh stack view --short` to inspect the stack, `gh stack up`/`down`/`top`/`bottom` to navigate, `gh stack rebase --continue` to resolve conflicts the same way as `git rebase`, and `gh stack unstack` to detach local tracking.

## Attachments in issues, PRs, and comments

`gh` 2.99.0 (September 1, 2026) added a repeatable `--attach` flag. It uploads a local image or video and references it inline in the body.

Works on `gh pr create`, `gh pr edit`, `gh pr comment`, `gh issue create`, `gh issue edit`, and `gh issue comment`:

```bash
gh pr create --title "..." --body "..." --attach './before.png#Before' --attach './after.png#After'
gh pr comment --attach ./screenshot.png
gh issue comment --attach ./repro.mp4
gh pr edit 456 --attach ./result.png
```

- Alt text follows the path after `#`. Without it, the filename is used.
- A local path already referenced in the body, such as `![alt](./login.png)`, is rewritten in place to point at the uploaded asset. Anything attached but never referenced is appended at the end.
- Formats: PNG, JPEG, GIF, WebP, SVG, MP4, MOV, WebM. Images and GIFs cap at 10 MB. Video caps at 10 MB on free plans and 100 MB on paid plans. One batch holds at most 50 files.
- Available on GitHub.com and GitHub Enterprise Cloud. Not GHES in the initial release.
- Requires write access to the target repository, using the OAuth token from `gh auth login` or a classic PAT.

**Hard rule, with no exceptions:** never attach secrets or personal images. No tokens, API keys, passwords, `.env` contents, SSH keys, or terminal output showing secret material, which in this dotfiles repo includes any `msr`, `msload`, or 1Password output. No private photos, identity documents, or screenshots exposing browser tabs, bookmarks, or account pages. Uploads land on GitHub's CDN where anyone with the URL can view them, and they cannot be reliably deleted afterwards. Read the image before attaching it and redact anything sensitive. If in doubt, describe it in text instead.

## Other `gh` changes worth knowing

- `gh skill` (v2.90.0, April 2026, preview) discovers, installs, updates, and publishes agent skills: `gh skill install github/awesome-copilot documentation-writer@v1.2.0`, `gh skill search mcp-apps`, `gh skill update --all`. Skills are not verified by GitHub and may contain prompt injections or malicious scripts.
- `gh issue` gained Issues 2.0 support (v2.94.0, June 2026): `--type`, `--parent`, `--add-sub-issue`, `--blocked-by`/`--blocking` and their add/remove variants. For example `gh issue create --type Bug` or `gh issue edit 123 --add-blocking 300`.
- `gh discussion` (v2.94.0, preview): `list`, `view --comments`, `create`, `edit`, `comment`.
- `gh repo read-file` and `gh repo read-dir` (v2.95.0, June 2026) read remote repository content without cloning, with `--ref`, `--json`, `--jq`, and `--template`.
- `gh release download` works unauthenticated for public repositories (v2.96.0).
- `gh pr checkout --worktree PATH` (v2.98.0, August 2026) and `gh issue develop --checkout --worktree` (v2.99.0) create worktrees directly, which pairs well with this repo's worktree rule.
- `gh pr diff --exclude`, `gh issue close --duplicate-of`, `gh repo clone --no-upstream`, and `gh browse --blame` arrived in v2.88.0.
- `gh auth login` now copies the auth code to the clipboard by default (v2.101.0). Opt out with `gh config set clipboard disabled`.

**Security fixes that are upgrade prompts:** v2.97.0 fixed terminal escape sequence injection across `gh gist view`, `gh api`, `gh pr diff`, `gh release download --output -`, and others; v2.92.0 fixed the same class in `gh run view --log`; v2.96.0 fixed command execution when connecting to a malicious Codespace through `gh codespace jupyter`. Keep `gh` current.

## Actions changes that affect how you write workflows

- **`actions/checkout` v7** refuses to fetch fork PR code in `pull_request_target` and `workflow_run` workflows, which blocks the common "pwn request" pattern. Opt out with `allow-unsafe-pr-checkout` and treat that as a deliberate security decision. The enforcement was backported to v2 through v6 in July 2026.
- **`cache-mode`** (GA September 2026) sets least-privilege cache access at workflow or job level: `read`, `write`, `write-only`, or `none`. Untrusted events default to read only.
- **Self-repository action syntax** `$/` resolves a `uses:` value to the workflow's own repository at the exact running commit, with no checkout needed. Requires runner 2.336.0 or newer.
- **Parallel steps** (beta, June 2026) run steps concurrently with `background: true`, plus `wait`, `wait-all`, and `cancel` keys.
- **Scheduled workflows** accept an IANA `timezone:` field next to `cron`.
- **Workflow execution protections** (GA September 2026) allowlist who can trigger a workflow and what events can start it, under Actions settings. A default rule disabling `pull_request_target` for public repositories without a matching policy gets enforced on November 2, 2026.
- **Retention now covers checks, workflow runs, and statuses**, effective October 1, 2026, governed by the Actions retention setting (default 90 days). This is not retroactive.
- **`ubuntu-latest` migrates from 24.04 to 26.04** between October 19 and November 19, 2026. Test against `ubuntu-26.04` or pin `ubuntu-24.04`.
- Workflows are limited to 50 reruns.
- **Agentic Workflows** (preview, June 2026) define reasoning-based automation in Markdown files that compile to Actions YAML, running read-only by default inside a sandboxed container.

## Repo security and settings

- **Block PRs with exposed secrets from merging** (preview, September 2026): in a branch ruleset, enable "Require secret scanning alerts are resolved". Requires GitHub Secret Protection or GHAS.
- **Convert branch protection rules to rulesets** automatically from Settings, Branches, "Convert to ruleset".
- **Restrict who can dismiss reviews in rulesets** (GA July 2026), configurable by users, teams, and apps.
- **Push rules path exceptions** (preview, August 2026) for restrict-file-paths and restrict-file-size.
- **Code coverage ruleset condition** is manageable through the REST API (GA September 2026).
- **Issue fields** went GA in July 2026. **"Relates to"** issue relationships and multi-select fields arrived in August 2026.
- **Archive pull requests** (July 2026) closes and locks them, hides them from everyone except repo admins, and returns 404 otherwise. Find them with `is:archived`.
- **Refreshed pull requests page** in public preview (September 2026), with a new dashboard at github.com/pulls (GA July 2026).
- **GitHub Code Quality** went GA in July 2026 as a paid product at $10 per active committer per month, separate from GHAS.

## Tokens, apps, and supply chain

- **GitHub App installation tokens changed format** starting April 27, 2026: `ghs_APPID_JWT`, roughly 520 characters. Treat tokens as opaque strings. Remove regexes like `ghs_[A-Za-z0-9]{36}` and widen database columns.
- **Immutable subject claims for Actions OIDC tokens** add owner and repo IDs to the `sub` claim, for example `repo:octocat@123456/my-repo@456789:ref:refs/heads/main`. Opt in per organization or repository. Repositories created after July 15, 2026 use the new format automatically. Update AWS, Azure, and GCP trust policies.
- **Credential revocation by token type** (August 2026) supports per-user revoke and deauthorize during an incident, at enterprise and organization level.
- **SHA-1 in HTTPS was disabled** for github.com and partner CDNs on September 15, 2026.
- **Dependabot reads private GitHub Packages registries without a PAT** as of September 2026, reusing the repository's "Manage Actions access" package grant.
- **Stage-only npm tokens** (September 2026) publish with `npm stage publish` and require maintainer approval. Direct `npm publish` with such a token is rejected even with 2FA bypass configured. Removal of direct publishing through bypass-2FA tokens is targeted for January 2027.
- **Secret scanning** added extended provider metadata (GA July 2026) and multipart validation covering key and host pairs across major cloud providers. The `secret_scanning_alert` webhook now includes a `secret_category` field.
- **CodeQL 2.27.0** added native Linux ARM64 support and a Rust `rust/command-line-injection` query.
- **Enforce GHAS configurations** (September 2026) lets enterprise admins prevent organization and repository admins from overriding settings.

## API notes

- **REST API version `2026-03-10`** is the first calendar version with breaking changes. Opt in with `X-GitHub-Api-Version: 2026-03-10`. Requests without the header still default to `2022-11-28`, which is supported for at least 24 months from March 2026.
- **GitHub MCP Server** supports the stateless MCP spec (sessions and the initialize handshake were removed as of July 28, 2026).
- **MCP allowlists** live in enterprise managed settings under `allowedMcpServers` and `deniedMcpServers`, and they fail closed.

## Working rules for this repo

The repo's own conventions still apply and this skill does not override them:

- Work on a feature branch and open a PR. Never push directly to `main`.
- Use squash merges only. `gh stack merge --squash` respects that for stacks.
- Always link PRs by full URL, `https://github.com/<owner>/<repo>/pull/<n>`.
- Babysit every PR until checks are green, then merge explicitly. Never use `gh pr merge --auto` on repositories without branch protection.
- Run `gh` non-interactively: set `GH_PROMPT_DISABLED=1` and pass all required fields explicitly.
- Add the attribution line to issue comments and PR descriptions: created on behalf of Ifiok Jr. (`@ifiokjr`), including the model and thinking level.

## Reference

`references/features-2026.md` lists every change found in the March to September 2026 window, with dates, preview status, and source URLs, including the Copilot, Issues, Projects, and platform changes summarized above but not detailed here.
