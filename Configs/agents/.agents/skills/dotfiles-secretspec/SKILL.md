---
name: dotfiles-secretspec
description: Dotfiles-specific SecretSpec + 1Password workflow for accessing tokens and API keys without ambient env injection. Use when working in ifiokjr/dotfiles, when commands need secrets like GITHUB_TOKEN or ANTHROPIC_API_KEY, or when editing SecretSpec, shell, Nushell, or agent setup.
---

# Dotfiles SecretSpec

This repository uses Ifiok's forked SecretSpec setup for secrets. Reference implementation: <https://github.com/ifiokjr/secretspec>.

## Core rule

Secrets are **not injected by default**. Do not assume `GITHUB_TOKEN`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc. exist in the ambient shell environment.

The dotfiles setup provides three modes:

- `ssr <command>`: preferred. Runs one command with SecretSpec secrets injected only for that subprocess.
- `ss get <name>`: get a single secret value by name. Writes to stdout, safe for command substitution. Example: `my_token=$(ss get GITHUB_TOKEN)`.
- `ssload`: convenience. Loads all declared SecretSpec secrets into the current shell session; use only when repeated commands need secrets.

`ss` is the SecretSpec CLI wrapper using `~/secretspec.toml`.

## Commands

Check configured secrets:

```sh
ss check
```

Get a single secret value (safe for command substitution):

```sh
my_token=$(ss get GITHUB_TOKEN)
```

Run a command with secrets lazily injected:

```sh
ssr gh pr list
ssr env | grep GITHUB_TOKEN
```

Load all secrets into the current shell session:

```sh
ssload
```

After `ssload`, normal commands can use secrets without `ssr` until the shell exits or variables are unset.

## Security guidance

Prefer `ssr <command>` because secrets stay scoped to a child process. Use `ssload` only for interactive sessions where convenience is worth keeping secrets in the current environment.

Never print full secret values in logs or chat. Use masked output if verification is needed.

## Implementation notes

- `~/secretspec.toml` is deployed from `Configs/secretspec/secretspec.toml`.
- `OP_SERVICE_ACCOUNT_TOKEN` is resolved through SecretSpec providers, normally keyring/keychain with optional dotenv or 1Password fallback.
- The fork supports provider dependencies so token-backed 1Password providers can depend on `OP_SERVICE_ACCOUNT_TOKEN`.
- POSIX shell helpers live in `Configs/shell/.config/shell/secrets.sh`.
- Nushell helpers live in `Configs/nushell/.config/nushell/modules/secrets.nu`.
