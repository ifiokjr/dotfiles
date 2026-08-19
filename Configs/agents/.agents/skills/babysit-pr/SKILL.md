---
name: babysit-pr
description: Use whenever the user asks to watch or maintain an open pull request until it merges or they say stop.
---

# Babysit Pull Request

Keep an open PR healthy and mergeable until it's merged or the user says stop: resolve conflicts with main, handle review feedback, fix CI, and hold the line on scope.

## The loop

Run this as a recurring check (cadence set by the caller) until the PR is merged, closed, or the user ends the session. Each cycle:

1. Check for conflicts with main and resolve them (rebase, or merge for merge-based branches)
2. Check CI status
3. Read new review feedback
4. Push fixes and replies
5. Report status to the user, including the full PR URL

## 1. Check for conflicts and rebase on main

- **Always check whether the PR has conflicts with `origin/main`** — resolving conflicts is a core part of babysitting, not an afterthought
- Check mergeability: `gh pr view --json mergeable,mergeStateStatus --jq '{mergeable, mergeStateStatus}'` (or `git fetch origin main` and compare against the branch)
- If the PR has conflicts with `origin/main`, resolve them by rebasing the branch on top of `origin/main`:
  - `git fetch origin main` then `git rebase origin/main`
  - Resolve conflicts with minimal changes that preserve intent from both sides
  - After rebasing, force-push with `--force-with-lease` (safe under squash-merge workflows)
- **Caveat — merge-based branches:** if the branch is based on merging (its history contains merge commits, e.g. `git log --oneline --merges origin/main..HEAD` returns anything), rebasing is unrealistic. In that case, merge `origin/main` into the branch instead (`git merge origin/main`) and push normally.
- Default is rebase; only fall back to merging when the branch is genuinely merge-based
- Only rebase when main has actually advanced or conflicts exist — don't churn

## 2. Address review feedback

- Read every new comment: AI/bot reviews (e.g. CodeRabbit), human reviewers, and inline threads
- Valid feedback — make the change, commit, and push
- False positives — never silently ignore; reply on the thread with a clear rationale for why the comment does not apply

## 3. Fix CI failures

- Check CI status after every push (`gh pr checks`)
- Fix failures promptly — red CI blocks review and merge
- If a failing check is flaky or broken and unrelated to the PR, state that in the report instead of hacking around it

## 4. Stop scope creep

- The PR's purpose is fixed; do not add features, refactors, or unrelated fixes to it
- New work surfaced during babysitting (bugs, ideas) goes to a new issue or PR — note it in the report
- Push back on anything that would balloon the PR and suggest a follow-up instead

## Reporting

After each cycle, give a concise status update: what was rebased/merged, conflicts resolved, fixed, or answered; current CI state; what's blocking; and always the full PR URL (`gh pr view --json url --jq .url`).

End every status update and PR comment with the attribution footer:

```
_Created on behalf of Ifiok Jr. ([@ifiokjr](https://github.com/ifiokjr)) by <harness> using <model> at <thinking level> thinking._
```

Fill in your real details — the harness (e.g. pi, codex), the model you are running (e.g. GPT-5.5, Claude, DeepSeek), and your thinking level. Do not guess; use what you know about your own configuration.

## Done

When the PR merges: report it, clean up (e.g. remove the worktree per the git-workflow skill), and stop. When the user says stop: stop.
