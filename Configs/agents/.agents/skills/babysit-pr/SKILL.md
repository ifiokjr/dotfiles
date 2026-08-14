---
name: babysit-pr
description: Monitor and maintain an open pull request until it merges. Use whenever the user asks to monitor,
  watch, or babysit a PR, or wants a PR kept up to date, review feedback handled, CI failures fixed, or scope
  creep stopped.
---

# Babysit Pull Request

Keep an open PR healthy and mergeable until it's merged or the user says stop: rebase on main, handle review feedback, fix CI, and hold the line on scope.

## The loop

Run this as a recurring check (cadence set by the caller) until the PR is merged, closed, or the user ends the session. Each cycle:

1. Rebase the branch on main
2. Check CI status
3. Read new review feedback
4. Push fixes and replies
5. Report status to the user, including the full PR URL

## 1. Rebase on main

- `git fetch origin main` then rebase the PR branch on it
- Only rebase when main has actually advanced — don't churn
- Resolve conflicts with minimal changes that preserve intent from both sides
- After rebasing, force-push with `--force-with-lease` (safe under squash-merge workflows)

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

After each cycle, give a concise status update: what was rebased, fixed, or answered; current CI state; what's blocking; and always the full PR URL (`gh pr view --json url --jq .url`).

End every status update and PR comment with the attribution footer:

```
_Created on behalf of Ifiok Jr. ([@ifiokjr](https://github.com/ifiokjr)) by <harness> using <model> at <thinking level> thinking._
```

Fill in your real details — the harness (e.g. pi, codex), the model you are running (e.g. GPT-5.5, Claude, DeepSeek), and your thinking level. Do not guess; use what you know about your own configuration.

## Done

When the PR merges: report it, clean up (e.g. remove the worktree per the git-workflow skill), and stop. When the user says stop: stop.
