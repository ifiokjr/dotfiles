---
name: dotfiles
description: Working in the ifiokjr/dotfiles ecosystem. Use when commands need secrets, shell aliases, devenv, the dot/dotfiles CLI, rebuild, deployment, or any task that runs inside this dotfiles-managed environment. Teaches agents how to use the shortcuts, secrets workflow, and tooling available on these machines.
---

# Dotfiles Ecosystem

These dotfiles manage a cross-platform (macOS/Linux) Nix-based development environment. The default shell is **Nushell** (not Bash). Configuration is deployed via [tuckr](https://github.com/RuktDaGmmer/tuckr) symlinks from `Configs/` groups and rebuilt with Nix/nix-darwin.

## Core Rules

1. **Shell is Nushell** — all interactive terminals use Nushell. Write commands in Nushell syntax, not Bash.
2. **Secrets are NOT ambient** — never assume `GITHUB_TOKEN`, `OPENAI_API_KEY`, etc. exist in the environment. Use the Monosecret workflow below.
3. **Prefer aliases** — use the short aliases instead of full commands. They exist for speed and correctness.

## Secrets (Monosecret + 1Password)

Secrets are declared in `~/monosecret.toml` and resolved at runtime via [Monosecret](https://github.com/ifiokjr/monosecret). The default profile uses 1Password providers; secret values must never be committed or written to ordinary plaintext files.

The dotfiles provide three Monosecret shortcuts. Each pins the managed `~/monosecret.toml` file and supplies an audit reason:

| Mode | Command | When to use |
|------|---------|-------------|
| **Manage** | `ms <command>` | Run Monosecret commands such as `check`, `get`, `set`, and `audit` |
| **Preferred** | `msr <command>` | Inject all resolved secrets into one child command, then discard them |
| **Session** | `msload` | Load all declared secrets into the current shell for repeated interactive use |

### Common workflows

```nu
# Verify required secrets can be resolved. Missing values may prompt for input.
ms check

# Run one command with secrets scoped to that child process.
msr gh pr list
msr cargo publish

# Resolve one value only when an API requires the raw value.
let github_token = (ms get GITHUB_TOKEN)

# Set a value interactively so it does not appear in shell history.
ms set GITHUB_TOKEN

# Review local secret-access records without resolving values.
ms audit

# Intentionally load every declared secret into this interactive shell.
msload
```

`msr` should receive a real executable, not a shell-only alias. For example, use `msr devenv shell cargo test` rather than `msr ds cargo test`.

### Provider bootstrap

`OP_SERVICE_ACCOUNT_TOKEN` bootstraps automated 1Password access. Monosecret can resolve it from the system keyring, interactive 1Password access, or the mode-600 `~/.env.dotfiles` fallback. Prefer the keyring. Use `setup:env --set-token` only when the keyring is unavailable or being reset; no other secrets belong in that fallback file.

### Security rules

- Prefer `msr` because secrets exist only in the child process.
- Use `msload` only for an intentional interactive session; it leaves secrets resident in that shell.
- `ms get <NAME>` writes the raw value to stdout. Never print, log, or paste its output into chat.
- Run `ms set <NAME>` without a value so Monosecret prompts securely instead of recording the value in shell history.
- Never assume secrets are ambient, and never copy resolved values into repository files.

### Troubleshooting

If a command fails with authentication, permission, or rate-limit errors:

1. Retry it with `msr <command>`.
2. Run `ms check` to identify unresolved required secrets.
3. If 1Password bootstrap fails, restore keyring access or use `setup:env --set-token` for the service-account-token fallback.
4. Use `msload` only when several interactive commands genuinely need the same environment.

Example: if `gh pr list` reports an authentication error, retry with `msr gh pr list`.

## Devenv (Development Environment)

Projects using [devenv](https://devenv.sh) get a managed shell with all dependencies. Always enter the devenv shell before running project commands.

| Alias | Command | Purpose |
|-------|---------|---------|
| `ds` | `devenv shell` | Enter the project's development shell |
| `de` | `devenv up` | Start the project's development services |

**Always prefix with `ds` when you need devenv:** `ds cargo test`, `ds pnpm build`, etc.
When commands need secrets and devenv, use the executable form `msr devenv shell cargo test`, or run `msload` before an interactive `ds cargo test` session.

## Dotfiles CLI (`dot` / `dotfiles`)

The `dotfiles` CLI (aliased as `dot`) manages the dotfiles installation.

| Command | Purpose |
|---------|---------|
| `dot setup` | Initial setup — install Nix, clone repo, deploy groups |
| `dot rebuild` | Rebuild system config (nix-darwin switch or home-manager switch) |
| `dot reload` | Re-deploy Tuckr symlinks without rebuilding Nix or changing the tracked `flake.lock` |
| `dot doctor` | Run preflight checks without changing the machine |
| `dot groups` | Manage config groups — list, deploy, undeploy |
| `dot machine` | Inspect/modify `machine.nix` (hostname, lite mode, presets) |
| `dot env` | Manage environment config and secrets |
| `dot pnpm` | Manage pnpm global packages |
| `dot version` | Print CLI version and environment info |

**Rebuild flags:** `--update` (update flake inputs), `--lite` / `--no-lite`, `--desktop` / `--no-desktop`, `--always-on`, `--add-preset`, `--rebuild-os`, `--dry-run`.

## Essential Aliases

### Monosecret

| Alias | Command |
|-------|---------|
| `ms` | `monosecret -f ~/monosecret.toml --reason "dotfiles secret management"` |
| `msr` | `monosecret -f ~/monosecret.toml --reason "dotfiles secret injection" run --` (alias, flags pass through) |
| `msload` | Load all secrets into the current shell session |

### Shell / Editor

| Alias | Command |
|-------|---------|
| `n` / `vim` | `nvim` |
| `hx` | Helix editor (`$EDITOR`) |
| `lg` | `lazygit` |
| `zj` | `zellij` (terminal multiplexer) |
| `cl` | `clear` |

### Dev Tools

| Alias | Command |
|-------|---------|
| `ds` | `devenv shell` |
| `de` | `devenv up` |
| `g` | `git` |
| `p` | `pnpm` |
| `co` | `codex --dangerously-bypass-approvals-and-sandbox` |
| `oc` | `opencode` |

### Docker (Podman)

| Alias | Command |
|-------|---------|
| `dk` | `docker` (podman compat) |
| `dkc` | `docker compose` |
| `dkcu` | `docker compose up -d` |
| `dkcd` | `docker compose down` |
| `dkcl` | `docker compose logs -f` |
| `dkce` | `docker compose exec` |
| `dkps` | `docker ps` |

### Nix

| Alias | Command |
|-------|---------|
| `nr` | `rebuild` |
| `nfc` | `nix flake check --flake ~/.config/nix` |
| `nfu` | `nix flake update --flake ~/.config/nix` |
| `ns` | `nix search nixpkgs` |
| `update` | `nix flake update --flake ~/.config/nix` |

### Rust / Cargo

| Alias | Command |
|-------|---------|
| `cr` | `cargo run` |
| `cb` | `cargo build` |
| `ct` | `cargo test` |
| `cch` | `cargo check` |
| `ccl` | `cargo clippy` |
| `cf` | `cargo fmt` |
| `cw` | `cargo watch -x run` |

### File Listing (lsd)

| Alias | Command |
|-------|---------|
| `l` | `lsd -lah` |
| `la` | `lsd -lAh` |
| `ll` | `lsd -lh` |
| `lls` | `lsd -G` |
| `lsa` | `lsd -lah` |

### Git (200+ aliases, key ones below)

See `Configs/nushell/.config/nushell/config.nu` for the full list. Most follow the [oh-my-zsh git plugin](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git) conventions.

| Alias | Command | When |
|-------|---------|------|
| `g` | `git` | Any git command |
| `gs` / `gst` | `git status` | Check repo state |
| `ga` | `git add` | Stage files |
| `gaa` | `git add --all` | Stage everything |
| `gc` | `git commit --verbose` | Commit with editor |
| `gca` | `git commit --verbose --all` | Commit all staged |
| `gcam` | `git commit --all --message` | Commit all with message |
| `gco` | `git checkout` | Switch branches |
| `gcb` | `git checkout -b` | Create new branch |
| `gp` | `git push` | Push |
| `gpf` | `git push --force-with-lease` | Force push safely |
| `gl` | `git pull` | Pull |
| `gpr` | `git pull --rebase` | Pull with rebase |
| `gd` | `git diff` | Diff |
| `glog` | `git log --oneline --decorate --graph` | Pretty log |
| `gb` | `git branch` | List branches |
| `gsta` | `git stash push` | Stash changes |
| `gstp` | `git stash pop` | Pop stash |
| `grb` | `git rebase` | Rebase |
| `grh` | `git reset` | Reset |
| `gw` | `git worktree` | Worktree management |

## Project Architecture

- **`Configs/`** — Tuckr config groups, each maps to `~/.config/<group>/` via symlinks
- **`Configs/nix/`** — Nix flake, `darwin.nix` (macOS), `home.nix` (packages), `machine.nix` (per-machine)
- **`Configs/monosecret/`** — `monosecret.toml` declaring all secrets and their 1Password paths
- **`Configs/nushell/`** — Nushell config, aliases, env, modules (including `secrets.nu`)
- **`Configs/shell/`** — POSIX shell env (bash/zsh), aliases
- **`Hooks/`** — Post-deploy scripts per config group (e.g. `Hooks/nix/post.sh` rebuilds)
- **`cli/`** — The `dotfiles`/`dot` Deno-compiled CLI binary

## Key Conventions

- **Package manager**: Nix (`nix profile add`; never `nix profile install`)
- **Shell**: Nushell is default; `$env.VAR` syntax, `^cmd` for externals, no `&&` (use `;` or `and`/`or`)
- **Git**: Conventional commits, feature branches (`feat/`, `fix/`, `ci/`), squash merges
- **Formatting**: dprint (`dprint check --config Configs/dprint/dprint.json`)
- **Rebuild**: `dot rebuild` or `nr` after any Nix config change
- **Verification**: `dot doctor` for preflight checks, `nfc` for flake check