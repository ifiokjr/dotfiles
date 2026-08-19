---
name: create-pr
description: Use whenever the user asks to create, open, or file a pull request.
---

# Create Pull Request

Open **full** pull requests (never drafts) that are ready to merge: a concise, human-readable title that doubles as the squash-commit message, and a problem-first description instead of a raw inventory of changes.

## Before creating

Match the repository's conventions:

- Check for a PR template (e.g. `.github/PULL_REQUEST_TEMPLATE.md`) and follow it
- Follow the repo's workflow: target branch, labels, commit conventions
- Create a **full PR — never a draft** unless the user explicitly asks for a draft

## PR Title

The PR title becomes the commit message when the PR is squash-merged, so write it as a concise conventional commit message:

- **Type** — `fix:`, `docs:`, `feat:`, `refactor:`, `test:`, `ci:`, `build:`, `chore:`
- **Breaking change** — add `!` after the type (and scope if present): `fix(api)!:`, `feat!:`
- **Scope** — add when it adds clarity: `fix(solana): ...`
- One line, imperative mood, describing what the PR does
- Match the branch's intent (a `feat/` branch gets a `feat:` title)

## PR Description

Lead with **why**, then **how**. Keep it concise and specific — no filler.

### 1. Why — the reason this PR exists (always first)

Describe the problem that prompted the PR — the reason it exists — not a raw inventory of what changed:

- What problem was the user facing, or what did they ask for?
- Capture any discussion that led to the PR — the context and decisions from the conversation, using the user's own framing where possible
- If the reason is not clear from the conversation, ask the user rather than inventing one

Example: "The settings screen took several seconds to render on device, making the app feel unresponsive. This PR was created to fix that slowness."

### 2. Implementation — how it solves the problem (after Why)

Briefly describe how the PR solves it:

- Approach taken and why
- Key areas or files changed
- Notable trade-offs or follow-ups

### 3. No Testing or Validation section

Never include `## Testing` or `## Validation` sections — for projects with CI and workflows set up, it's redundant. The validation happens in CI; it doesn't need to be repeated in the description. Unless the user explicitly asks you to specify what was tested and how you validated the code, don't include it — just explain what you did in Implementation.

## Attribution footer

End every PR description with who created it and how:

```
_Created on behalf of Ifiok Jr. ([@ifiokjr](https://github.com/ifiokjr)) by <harness> using <model> at <thinking level> thinking._
```

Fill in your real details — the harness (e.g. pi, codex), the model you are running (e.g. GPT-5.5, Claude, DeepSeek), and your thinking level. Do not guess; use what you know about your own configuration.

## Checklist

- [ ] Created as a **full PR, not a draft** (unless explicitly asked)
- [ ] Followed the repository's PR template and conventions
- [ ] Title is a concise, human-readable conventional commit message (with `!` for breaking changes)
- [ ] Description opens with the reason the PR was created — a problem, not an inventory of changes
- [ ] Implementation details come after the why
- [ ] No Testing/Validation section (CI covers it) unless the user explicitly asked
- [ ] Attribution footer: on behalf of Ifiok Jr. (@ifiokjr), harness, model, thinking level
- [ ] No generic filler like "This PR fixes stuff"
