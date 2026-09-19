# GitHub changes, March to September 2026

The full inventory behind `SKILL.md`, most impactful first, with dates, preview status, and source URLs. Verified September 19, 2026 against the GitHub Changelog, the `gh` CLI release notes, the gh-stack README, and GitHub Docs.

## Stacked pull requests

Public preview, July 30, 2026. Splits one large change into an ordered chain of small PRs, each targeting the layer below, so reviewers see only that layer's diff. Native to GitHub: existing reviews, required checks, and branch protections apply. A stack can land all at once or layer by layer. Rolled out to all repositories; no opt-in flag. Works on GitHub Mobile.

Merge behavior: merging the latest ready PR lands it and every unmerged layer below. Merging a lower layer leaves upper PRs open, automatically rebased and retargeted. Merge queue support rolled out progressively after launch.

Source: https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview

Related: "Stacked sessions and pull requests in the GitHub Copilot app" (July 30, 2026) and "Turn one giant AI-generated pull request to a reviewable stack" (August 4, 2026).

### gh-stack extension commands

| Command | Purpose and key flags |
| --- | --- |
| `gh stack init [flags] [branches...]` | Initialize or attach a stack. `-b/--base <branch>` defaults to the repo default branch. Enables git rerere automatically. |
| `gh stack add [flags] [branch]` | Add a branch on top of the current stack. `-A/--all`, `-u/--update` (both require `-m`), `-m/--message <string>`. `-A` and `-u` are mutually exclusive. Must be on the topmost branch. |
| `gh stack checkout [<stack#> \| <pr#> \| <pr-url> \| <branch>]` | Check out by stack number, PR number, URL, or branch. No args opens a searchable picker with All, Local, and Remote tabs. |
| `gh stack rebase [flags] [branch]` | `--downstack`, `--upstack`, `--no-trunk`, `--continue`, `--abort`, `--remote <name>`, `--committer-date-is-author-date`. Switches to `--onto` mode automatically if a branch's PR was merged. |
| `gh stack modify [flags]` | Interactive TUI: drop, fold, insert, reorder, rename, undo. Avoid in agent runs unless asked. |
| `gh stack sync [flags]` | Fetch, reconcile the remote stack, fast-forward trunk, cascade rebase, push (force-with-lease after a rebase), sync PR state, link open PRs. Never opens PRs. `--remote <name>`, `--prune`. |
| `gh stack push [flags]` | Pushes all active branches in one push with explicit per-branch `--force-with-lease`. Not atomic. Does not create or update PRs. |
| `gh stack submit [flags]` | Creates a PR per branch, pushes, creates the stack. `--auto` skips the editor, `--open` marks PRs ready for review, `--remote <name>`. |
| `gh stack link [flags] <branch-or-pr> ...` | Creates or updates a GitHub stack without local tracking. Arguments run bottom to top. Additive only, never removes existing PRs. |
| `gh stack merge [<stack#> \| <pr#>]` | `--merge-method <merge\|squash\|rebase>` with shorthands, `-y/--yes`. Merges the chosen PR and every unmerged layer below it. |
| `gh stack view [flags]` | `-s/--short`, `--json`. Shows branches, ordering, PR links, and latest commit. |
| `gh stack unstack [<stack#>] [flags]` | Alias `delete`. `--local` removes local tracking only. Queued or auto-merge PRs stay stacked. |
| Navigation | `gh stack up [n]`, `down [n]`, `top`, `bottom`, `trunk`, `switch`. Commands clamp to stack bounds. |
| `gh stack feedback [title]` | Opens a GitHub Discussion. |
| `gh stack alias [name]` | Installs a `gs` wrapper. `--remove` uninstalls it. |

Merge semantics and limits:

- Merge is all or nothing for the selected range. If any PR cannot merge, none do.
- Only basic PR state (open, not a draft) is pre-checked. GitHub evaluates branch protection and rules at merge time. Bypassing merge requirements is not supported for stacked merges.
- With a merge queue on the base branch, the stack is queued instead of merged directly. The queue chooses the merge method, so `--merge`, `--squash`, or `--rebase` is ignored with a warning, and PRs may land in separate groups.
- `gh stack push` is not atomic. Windows gets no automatic alias. `sync` never opens PRs.
- Terminal theme detection can fail over SSH or tmux. Set `GH_STACK_THEME=auto|light|dark`. Hyperlinks are controlled by `GH_STACK_HYPERLINKS`.
- Exit codes: 0 success, 1 generic, 2 not in a stack or not found, 3 rebase conflict, 4 API failure, 5 invalid arguments, 6 disambiguation required, 7 rebase already in progress, 8 stack locked.
- Local metadata lives in `.git/gh-stack` and rebase state in `.git/gh-stack-rebase-state`. Neither is committed.

Source: https://github.com/github/gh-stack

## gh CLI attachments

Generally available September 1, 2026 in `gh` 2.99.0. No preview period. Available on GitHub.com and GitHub Enterprise Cloud, not GHES in the initial release.

The repeatable `--attach` flag uploads a local image or video and references it inline in the body. It works on `gh issue create`, `gh issue edit`, `gh issue comment`, `gh pr create`, `gh pr edit`, and `gh pr comment`.

- Formats: PNG, JPEG, GIF, WebP, SVG, MP4, MOV, WebM.
- Size limits: 10 MB for images and GIFs. Video caps at 10 MB on free plans and 100 MB on paid plans. A batch holds at most 50 files.
- Alt text follows the path after `#`. Without it, the filename is used.
- A local path already referenced in the body is rewritten in place, preserving alt text. Anything attached but never referenced is appended at the end.
- Requires write access, using the OAuth token from `gh auth login` or a classic PAT.

Sources: https://github.blog/changelog/2026-09-01-github-cli-media-in-issues-pull-requests-and-comments and https://github.com/cli/cli/releases/tag/v2.99.0

## GitHub Actions

### Security and policy

- Workflow execution protections, GA September 17, 2026 (preview June 18). An allowlist for who can trigger a workflow and which events can start it, under Actions settings in a new Policies section. GA added workflow file targeting, an Insights dashboard, a REST API, and kept evaluate mode. A default rule disabling `pull_request_target` for public repositories without a matching event policy gets enforced automatically on November 2, 2026.
- `actions/checkout` v7, GA June 18, 2026. Refuses to fetch fork PR code in `pull_request_target` and `workflow_run` workflows, blocking common "pwn request" patterns. Opt out with `allow-unsafe-pr-checkout`. Enforcement was backported in July 2026 to v2 through v6. v1 does not receive it. Floating major tags pick it up automatically; SHA or minor pins need an upgrade.
- Actions holds potentially malicious workflow runs for approval, beta July 28, 2026. Automatic, no configuration. The run waits for a collaborator with write access to approve it in an authenticated web session. Public repos on github.com only.
- Read-only Actions cache for untrusted triggers, June 26, 2026.
- Bot-created PRs can run workflows if approved, June 11, 2026.

### Syntax and capabilities

- `cache-mode`, GA September 10, 2026. Least-privilege cache access at workflow or job level, with values `read`, `write`, `write-only`, and `none`. Untrusted events such as `pull_request_target` default to read.
- Self-repository action syntax `$/`, GA July 30, 2026. A `uses:` value starting with `$/` resolves to the workflow's own repository at the exact running commit, with no checkout. Requires runner 2.336.0 or newer.
- Parallel steps, beta June 25, 2026. Steps run concurrently with `background: true`, plus `wait`, `wait-all`, `cancel`, and `parallel` keys.
- Scheduled workflow timezones, March 19, 2026. An IANA `timezone:` field next to `cron`.
- Environments without auto-deployment, March 19, 2026. The `deployment: false` key accesses an environment without creating a deployment.
- Service container `entrypoint` and `command` overrides, April 2, 2026.
- OIDC claims from repository custom properties, GA April 2, 2026.
- Reusable workflow context properties `job.workflow_ref`, `job.workflow_sha`, `job.workflow_repository`, and `job.workflow_file_path`, September 3, 2026.
- New `vulnerability-alerts` permission for `GITHUB_TOKEN`, September 3, 2026. Read-only Dependabot alert access.
- REST API for runner version deprecations, September 3, 2026. `GET /actions/runners/deprecations/{version}`.
- Larger concurrency queues, May 7, 2026. Custom images built from custom images, June 18, 2026.

### Runner images

- Ubuntu 26.04, GA September 17, 2026. `runs-on: ubuntu-26.04` or `ubuntu-26.04-arm`. `ubuntu-latest` migrates from 24.04 to 26.04 gradually between October 19 and November 19, 2026.
- Xcode 27 on macOS 27, September 10, 2026.
- Windows 11 arm64 VS2026, GA August 20, 2026.
- Red Hat Enterprise Linux images, preview June 25, 2026.
- May 14, 2026 migrations: GitHub now owns and maintains Arm64 runner images. `windows-latest` and `windows-2025` moved to Visual Studio 2026 between June 8 and 15, 2026 (pin `windows-2022` to stay on VS 2022). `macos-latest` moved to macOS 26 starting June 15, 2026 (pin `macos-15` to stay).
- Custom images for GitHub-hosted runners, GA March 26, 2026.
- Actions Runner Controller 0.14.0, March 19, 2026.

### Retention and breaking changes

- Retention now covers checks, workflow runs, and statuses, effective October 1, 2026. Previously kept 400 or more days regardless of configuration. Now governed by the Actions retention setting, default 90 days, with public repos capped at 90 for these items. Not retroactive. Metadata is not billed for storage.
- Workflows are limited to 50 reruns, April 10, 2026.

### GitHub Agentic Workflows

Preview June 11, 2026. Automates reasoning-based tasks such as issue triage, CI failure analysis, and docs updates using coding agents inside Actions. You define the automation in natural language Markdown files that compile into standard Actions YAML, reusing existing runner groups and policy constraints. Agents run read-only by default, execute inside a sandboxed container behind the Agent Workflow Firewall, and their outputs pass through a safe outputs process with a threat detection job scanning proposed changes. Agentic workflows no longer need a PAT as of June 11, 2026.

## GitHub CLI beyond stack and attach

| Change | Version | Date | Notes |
| --- | --- | --- | --- |
| `gh skill` command group, preview | v2.90.0 | April 16, 2026 | Discover, install, update, and publish agent skills. `--pin <tag\|sha>`, `--agent`, `--scope`. Skills are not verified by GitHub and may contain prompt injections, hidden instructions, or malicious scripts. |
| `gh issue` Issues 2.0 support | v2.94.0 | June 10, 2026 | `--type`, `--parent`, `--set-parent`, `--remove-parent`, `--add-sub-issue`, `--blocked-by`/`--blocking` with add and remove variants. New JSON fields for parent, sub-issues, type, and dependencies. |
| `gh discussion` command group, preview | v2.94.0 | June 10, 2026 | `list`, `view --comments`, `create`, `edit`, `comment`. |
| `gh repo read-file` and `gh repo read-dir` | v2.95.0 | June 17, 2026 | Read remote repository content without cloning. `--ref`, `--json`, `--jq`, `--template`. Also on GHES. |
| `gh release download` without auth | v2.96.0 | July 2, 2026 | Public repository release assets download unauthenticated. The token is still used when present. |
| `gh project` name-based fields and items | v2.97.0 | July 31, 2026 | Named field columns; name-based project fields and items. |
| `gh pr checkout --worktree PATH`, issue search `--search-type` | v2.98.0 | August 20, 2026 | Worktree support in `pr checkout`. Security: `gh codespace ports forward` bound the forwarded port to all interfaces by default. |
| `gh issue develop --checkout --worktree` | v2.99.0 | September 1, 2026 | Worktree checkout for issue develop. |
| Custom API host routing, experimental | v2.100.0 | September 3, 2026 | Per-host `api_host` config. Explicitly not a security boundary. Also full command help for coding agents. |
| `gh auth login` clipboard default, Linux key rotation | v2.101.0 | September 15, 2026 | Auth codes copy to the clipboard by default; opt out with `gh config set clipboard disabled`. The Linux APT and RPM signing key was rotated because the old key expired September 5. |
| Copilot Code Review as a PR reviewer, `gh issue close --duplicate-of`, `gh pr diff --exclude`, `gh repo clone --no-upstream`, `gh browse --blame` | v2.88.0 | March 10, 2026 | First-class Copilot code review reviewer selection. |

Security fixes worth upgrading for:

- v2.97.0 (July 31): terminal escape sequence injection in `gh gist view`, `gh api`, `gh pr diff`, `gh release download --output -`, `gh codespace logs`, `gh skills preview`, and `gh agent-task`, plus URL path metacharacter, token exposure in `gh auth status`, and regex metacharacter issues in `gh attestation verify`.
- v2.96.0 (July 2): command execution when connecting to a malicious Codespace through `gh codespace jupyter`.
- v2.93.0 (May 27): authorization header incorrectly included in API requests to TUF mirrors.
- v2.92.0 (April 28): terminal escape sequence injection in `gh run view --log` and `--log-failed`.

Releases checked for this window: v2.88.0 (March 10), v2.88.1 (March 12), v2.89.0 (March 26), v2.90.0 (April 16), v2.91.0 (April 22), v2.92.0 (April 28), v2.93.0 (May 27), v2.94.0 (June 10), v2.95.0 (June 17), v2.96.0 (July 2), v2.97.0 (July 31), v2.98.0 (August 20), v2.99.0 (September 1), v2.100.0 (September 3), v2.101.0 (September 15).

## Copilot

- Copilot code review can approve PRs, preview September 1, 2026. Off by default, configurable at enterprise, org, or repo level, with repo admins choosing which paths Copilot may approve. An approval counts toward required approvals when enabled.
- Improved review experience, GA September 18, 2026. Refreshed overview comment with the effort level used, and findings grouped as Open, Resolved since last review, and Previously missed. Auto-resolution honors a reply asking to keep an issue open and resolves comments marked Won't Fix or Incorrect. Batch suggestions get smart commit titles.
- Effort levels Lite and Balanced, GA August 7, 2026. Replaces the preview Low and Medium labels. Set per review, with an org default.
- Agent skills and MCP in code review, GA July 29, 2026. `AGENTS.md` support and UI improvements, June 18, 2026.
- GitHub Copilot app, GA June 17, 2026. macOS, Windows, Linux. Start sessions from an issue, PR, or prompt; run parallel sessions each on its own branch and worktree; review diffs and open PRs using existing checks and merge requirements. Added canvases, cloud automations, and BYOK with MCP tools.
- Agent apps, beta June 2, 2026. Partner AI agents installable from the Marketplace, invoked by assigning an issue, mentioning in a PR comment, or selecting in the Agents UI.
- Agent finder, GA June 17, 2026. Implements the ARD (Agentic Resource Discovery) spec. No auto-installation and no silent connections.
- Agent Plugins 1.0, GA August 12, 2026. An open standard packaging agent skills and MCP servers into one installable plugin, published with AWS, Anysphere, Microsoft, OpenAI, and Vercel, with Google as a core maintainer. Supported in VS Code, Copilot CLI, Copilot SDK, and the Copilot app.
- Enterprise managed permissions for agent operations, GA September 9, 2026. Admins block, require approval, or allow shell commands, file reads and edits, and network domains. Managed restrictions cannot be weakened by user settings or saved approvals.
- MCP allowlists in enterprise managed settings, GA August 6, 2026. `allowedMcpServers` and `deniedMcpServers` in `copilot/managed-settings.json`, matched on `serverUrl`, `serverCommand`, and `serverName`. Policies fail closed.
- Copilot cloud agent signs its commits, April 3, 2026. Configurable reasoning level, August 3, 2026. Sandboxes, preview June 2, 2026.

## Issues, Projects, and repository workflow

- Block PRs with exposed secrets from merging, preview September 9, 2026. In a branch ruleset, enable "Require secret scanning alerts are resolved". REST rule type `require_secret_scanning_alert_resolution`. Requires GitHub Secret Protection or GHAS.
- Automatically migrate branch protection rules to repository rulesets, August 11, 2026. Settings, Branches, then "Convert to ruleset".
- Restrict who can dismiss reviews in rulesets, GA July 7, 2026. Choose users, teams, and apps.
- Push rules path exceptions, preview August 25, 2026. For restrict file paths and restrict file size.
- Code coverage ruleset condition through the REST API, GA September 18, 2026.
- Rule insights dashboard, GA August 25, 2026. Organization insights, preview August 12, 2026.
- Pull request limits at organization level, August 6, 2026, under Moderation tools, Interaction limits. Related: limiting open PRs for users without write access (June 17, 2026) and restricting issue creation to collaborators only (June 29, 2026).
- Repository admins can archive pull requests, July 16, 2026. Archived PRs are closed, locked, visible only to repo admins, and return 404 to everyone else. Find them with `is:archived`.
- Issue fields, preview March 12, 2026 and GA July 2, 2026. "Relates to" relationships and multi-select field support, August 7, 2026.
- Agent automation controls in Issues, preview July 23, 2026. Agents rate actions high, medium, or low confidence, record a rationale, and let you accept or decline individually or in bulk. Covers labels, fields, type, close, and assignees. Approvals are a workflow convenience, not a security control.
- Saved views for repository issues, preview June 25, 2026, pinned to the sidebar GA August 20, 2026. Label archiving, GA August 27, 2026.
- Refreshed pull requests page, preview September 10, 2026. New dashboard at github.com/pulls, GA July 9, 2026.
- GitHub Code Quality, GA July 20, 2026. CodeQL deterministic analysis plus AI-assisted detection on PRs with Copilot Autofix, org-level enablement, cross-repo dashboards, Cobertura XML coverage reporting, quality gates via rulesets, and APIs. Paid product at $10 per active committer per month, not bundled with GHAS and not on GHES at launch.

## Security: secret scanning, CodeQL, Dependabot

### Secret scanning

- Extended metadata, GA July 7, 2026. Provider metadata such as owner, creation date, expiry date, and project context, surfaced in views, filters, campaigns, webhooks, and the REST API. Multipart validity checks now cover key-and-host pairs across major providers.
- Coverage, beta August 7, 2026. New partner Lovable Labs. New default push protection detectors for `apiclub_api_key`, `mistral_ai_api_key`, `posthog_oauth_access_token`, and `resend_api_key`.
- July 15, 2026: the `secret_scanning_alert` webhook gained a `secret_category` field, with `default` for provider and custom patterns and `generic` for generic patterns and AI-detected secrets.
- Push protection exemptions from repository settings, March 23, 2026, and for roles, teams, and apps, March 17, 2026.
- Custom patterns via the REST API, July 13, 2026. Public monitoring for enterprises, July 1, 2026.

### Code scanning

- AI Scan no longer requires CodeQL default setup, preview September 16, 2026. Works with scanning enabled at repo, org, or enterprise level, with no new setup step. GHAS customers only, github.com only.
- CodeQL 2.27.0, September 9, 2026. Native Linux ARM64 support with `linux-arm64` assets, org private registry configurations in default setup, Micronaut modeling for Java and Kotlin, C and C++ PostgreSQL libpq sinks, a Rust `rust/command-line-injection` query, and improved GitHub Actions author-association checks. Java 9 and 10 support is deprecated, with removal in January 2027.
- CodeQL 2.26.0 added AI prompt injection detection, July 10, 2026.
- Mitigated alert dismissal reason, August 20, 2026. Periodic code scanning of inactive repositories, June 9, 2026. Linking code scanning alerts to GitHub Issues, April 14, 2026.
- Enforce GitHub Advanced Security configurations, September 15, 2026. Enterprise admins enforce GHAS configurations across organizations, preventing org and repo admins from overriding enterprise settings.

### Dependabot

- Automatic access to GitHub-hosted registries, September 8, 2026. Dependabot reads private GitHub Packages registries without a PAT, reusing the repository's Manage Actions access package grant, and its token can request `packages: read`. First released June 23, 2026, rolled back, then re-enabled as fallback authentication where explicit credentials take precedence.
- Default package cooldown for version updates, July 14, 2026.
- Malicious package alerts across more ecosystems, July 28, 2026. Deno ecosystem support, June 9, 2026. sbt support, May 26, 2026. Nix support and AI-agent-assignable alerts, April 7, 2026. Python dependency graphs, April 23, 2026. npm malware detection, March 17, 2026. Xcode and SwiftPM `.xcodeproj` manifests, March 31, 2026. Alert assignees, GA March 3, 2026.

### npm supply chain

Stage-only npm tokens, September 18, 2026. Granular access tokens created with "Read and write (stage only)" publish with `npm stage publish` and require maintainer approval. npm rejects direct `npm publish` with such a token even when configured to bypass 2FA for automation. Requires 2FA on the npm account, npm CLI 11.15.0 or newer, and Node 22.14.0 or newer. npm is targeting January 2027 to remove direct publishing through bypass-2FA tokens. Related: multiple trusted publishing configurations for npm (September 3, 2026), publish-time malware scanning and dual-use metadata (July 28, 2026), and staged publishing with install-time controls (May 22, 2026).

## API, webhooks, MCP, GitHub Apps, and tokens

### API

- REST API version `2026-03-10`, GA March 12, 2026. The first calendar version with breaking changes. Opt in with `X-GitHub-Api-Version: 2026-03-10`. Requests without the header still default to `2022-11-28`, which stays fully supported for at least 24 months from March 2026.
- Privacy-safe star history endpoint, beta September 4, 2026. Returns historical star counts with timestamps without exposing stargazer identities.
- Enterprise installation API, preview May 13, 2026. GitHub Apps can access enterprise billing data, August 26, 2026. Enterprises can install third-party GitHub Apps, August 7, 2026. Budget and usage management APIs, GA June 4, 2026.
- Deprecations: `code_scanning_upload` removed from the `rate_limit` endpoint (deprecated May 5, removed May 19, 2026). Synchronous SBOM API deprecated May 12, 2026. Security-related organization API fields deprecated April 21, 2026.
- Webhooks: the notable in-window change is the `secret_scanning_alert` `secret_category` field on July 15, 2026.
- SCIM user responses now include a `profileUrl` attribute, September 16, 2026.

### GitHub Apps, tokens, and OIDC

- New GitHub App installation token format starting April 27, 2026. The new stateless format is `ghs_APPID_JWT`, roughly 520 characters, replacing the fixed 40-character form while keeping the `ghs_` prefix. Staged rollout: April 27 to mid-May for first-party integrations and the Actions `GITHUB_TOKEN`, then broader rollout with a brownout. Existing tokens work until they expire. GHES is unaffected. Treat tokens as opaque strings, remove regexes like `ghs_[A-Za-z0-9]{36}`, and widen database columns to hold at least 520 characters.
- Per-request installation override header for GitHub App tokens, May 15, 2026.
- Immutable subject claims for Actions OIDC tokens. The default `sub` gains immutable owner and repo IDs, for example `repo:octocat@123456/my-repo@456789:ref:refs/heads/main`, with `@` as the delimiter. Opt in at org or repo level, and inspect the new format with a preview endpoint. Repositories created after July 15, 2026 use the new format automatically, as do renames and transfers after that date. Existing repos are unaffected unless they opt in. Update AWS, Azure, and GCP trust policies.
- Credential revocation and deauthorization by token type, August 18, 2026. Revoke or deauthorize by token type, optionally for a specific user, during an incident, at enterprise and organization level. Actions are audit-logged with email notification. Actors: enterprise owners, org admins, and members with the Manage enterprise credentials permission.
- Automate SSO authorization for classic PATs and SSH keys, September 16, 2026. Self-service credential revocation for incident response, June 24, 2026.
- Multiple redirect URIs and token refresh for OAuth apps, August 14, 2026.
- SHA-1 in HTTPS disabled for github.com and partner CDNs on September 15, 2026, including GHEC and GHEC with Data Residency. GHES is unaffected.
- IP allow list coverage for EMU namespaces, GA June 8, 2026.
- Enterprise Teams, GA June 4, 2026. Enables team-targeted model policy, cost centers, and managed-settings specialization.

### MCP

- GitHub MCP Server supports the next stateless MCP specification, July 23, 2026. Sessions and the initialize handshake were removed as of July 28, 2026. Redis sessions removed, deep packet inspection avoided, elicitation implementation upgraded.
- MCP allowlists in enterprise managed settings, GA August 6, 2026. `allowedMcpServers` and `deniedMcpServers` keys in `copilot/managed-settings.json`, committed to the default branch of the source org's `.github-private` repository. Matchers are `serverUrl`, `serverCommand`, and `serverName`. Enforcement covers the Copilot app, Copilot CLI, and VS Code, and policies fail closed.
- Secret scanning through the GitHub MCP Server, GA May 5, 2026. Dependency scanning through MCP, preview May 5, 2026.

## Platform and GHES

- GHES 3.22 GA September 8, 2026. GHES 3.21 GA June 11, 2026. GHES 3.20 GA March 17, 2026.
- Enterprise Live Migrations from GHES to ghe.com, GA September 1, 2026. Migrate from GitLab with GitHub Enterprise Importer, August 3, 2026.
- New customer portal at help.github.com, September 8, 2026.
- Retirements in this window: GitHub Models fully retired July 30, 2026. GitHub Spark on github.com deprecation announced August 4, 2026. GitHub Classroom deprecated August 27, 2026. Custom thread subscriptions deprecated August 10, 2026. Copilot Billing Preview app retired August 3, 2026.

## Gaps

These were checked and nothing new was found in the window:

- Merge queue: no standalone 2026 changelog post. The only in-window news is stacked-PR merge queue support and gh-stack's documented behavior.
- Artifact attestations: no 2026 changelog entries.
- Action pinning policy: the SHA-pinning enforcement feature dates to August 15, 2025, outside the window. No newer pinning change was verified.
- Immutable releases: GA October 28, 2025, outside the window. No 2026 changes found.
- Webhooks: only the `secret_scanning_alert` `secret_category` field.
