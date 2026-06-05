---
name: dotfiles
description: Working in the ifiokjr/dotfiles ecosystem. Use when commands need secrets, shell aliases, devenv, the dot/dotfiles CLI, rebuild, deployment, or any task that runs inside this dotfiles-managed environment. Teaches agents how to use the shortcuts, secrets workflow, and tooling available on these machines.
---

# Dotfiles Ecosystem

These dotfiles manage a cross-platform (macOS/Linux) Nix-based development environment. The default shell is **Nushell** (not Bash). Configuration is deployed via [tuckr](https://github.com/RuktDaGmmer/tuckr) symlinks from `Configs/` groups and rebuilt with Nix/nix-darwin.

## Core Rules

1. **Shell is Nushell** — all interactive terminals use Nushell. Write commands in Nushell syntax, not Bash.
2. **Secrets are NOT ambient** — never assume `GITHUB_TOKEN`, `OPENAI_API_KEY`, etc. exist in the environment. Use the SecretSpec workflow below.
3. **Prefer aliases** — use the short aliases instead of full commands. They exist for speed and correctness.

## Secrets (SecretSpec + 1Password)

Secrets live in 1Password, resolved at runtime via [SecretSpec](https://github.com/ifiokjr/secretspec). They are **never** written to disk in plaintext.

| Mode | Command | When to use |
|------|---------|-------------|
| **Preferred** | `ssr <command>` | Run one command with all secrets injected ephemerally |
| **Single** | `ss get <NAME>` | Get one secret value (safe for command substitution) |
| **Session** | `ssload` | Load all secrets into current shell (only for repeated use) |

`ss` is an alias for the `secretspec` CLI using `~/secretspec.toml`.

**Examples:**

```sh
# Run gh with secrets
ssr gh pr list

# Get a single token for scripts
my_token=$(ss get GITHUB_TOKEN)

# Load all secrets for an interactive session
ssload
```

**Security:**
- Prefer `ssr` — secrets stay scoped to a child process.
- Never print full secret values in logs or chat.
- `ssload` is acceptable for interactive sessions but not recommended for automation.

**When a command fails due to missing secrets:**
If a command fails with auth errors, "permission denied", rate limiting, or missing token errors, it likely needs a secret that isn't in the ambient environment. Fix it by retrying with SecretSpec:

1. **Try `ssr <command>`** — rerun the failing command with all secrets injected ephemerally. This is the preferred fix.
2. **Try `ss get <NAME>`** — if you know which secret is missing, fetch it and set it manually.
3. **Try `ssload`** — load all secrets into the current session, then retry the command.

Example: if `gh pr list` fails with "authentication required", run `ssr gh pr list` instead.

## Devenv (Development Environment)

Projects using [devenv](https://devenv.sh) get a managed shell with all dependencies. Always enter the devenv shell before running project commands.

| Alias | Command | Purpose |
|-------|---------|---------|
| `ds` | `devenv shell` | Enter the project's development shell |
| `de` | `devenv up` | Start the project's development services |

**Always prefix with `ds` when you need devenv:** `ds cargo test`, `ds pnpm build`, etc.
When commands need secrets AND devenv, combine: `ssr ds cargo test` or `ssload` then `ds cargo test`.

## Dotfiles CLI (`dot` / `dotfiles`)

The `dotfiles` CLI (aliased as `dot`) manages the dotfiles installation.

| Command | Purpose |
|---------|---------|
| `dot setup` | Initial setup — install Nix, clone repo, deploy groups |
| `dot rebuild` | Rebuild system config (nix-darwin switch or home-manager switch) |
| `dot reload` | Re-deploy tuckr symlinks without rebuilding |
| `dot doctor` | Run preflight checks without changing the machine |
| `dot groups` | Manage config groups — list, deploy, undeploy |
| `dot machine` | Inspect/modify `machine.nix` (hostname, lite mode, presets) |
| `dot env` | Manage environment config and secrets |
| `dot pnpm` | Manage pnpm global packages |
| `dot version` | Print CLI version and environment info |

**Rebuild flags:** `--update` (update flake inputs), `--lite` / `--no-lite`, `--desktop` / `--no-desktop`, `--always-on`, `--add-preset`, `--rebuild-os`, `--dry-run`.

## Essential Aliases

### SecretSpec

| Alias | Command |
|-------|---------|
| `ss` | `secretspec -f ~/secretspec.toml` |
| `ssr` | `secretspec run -f ~/secretspec.toml --` (alias, flags pass through) |
| `ssload` | Load all secrets into current Nushell session |

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
- **`Configs/secretspec/`** — `secretspec.toml` declaring all secrets and their 1Password paths
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