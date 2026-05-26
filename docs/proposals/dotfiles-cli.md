# Proposal: `dotfiles` CLI — Unified Management Command

> **Status:** Draft  
> **Branch:** `feat/dotfiles-cli`  
> **Author:** Uche (with ifiokjr)

## tl;dr

Build a Deno-based CLI called `dotfiles` that becomes the single entry point for managing every aspect of this dotfiles repo — setup, rebuild, reload, reset, group management, doctor, and more. It replaces the current ad-hoc collection of bash/nushell scripts scattered across the repo with a cohesive, discoverable, interactive interface.

```bash
dotfiles help          # see everything available
dotfiles setup         # initial setup (replaces ./setup)
dotfiles rebuild       # rebuild nix + redeploy (replaces rebuild)
dotfiles reload        # tuckr reload all groups (replaces tuckr:reload)
dotfiles doctor        # preflight checks (replaces ./setup --doctor)
dotfiles groups list   # list config groups (replaces ./setup --list-groups)
dotfiles groups info nix  # explain a group (replaces ./setup --explain-group)
dotfiles machine config # inspect/edit machine.nix
dotfiles machine set-lite on   # toggle lite mode
dotfiles machine set-desktop on # toggle desktop mode
dotfiles machine add-preset ironclaw  # add a machine preset
dotfiles machine remove-preset ironclaw  # remove a machine preset
dotfiles uninstall     # full uninstall (replaces uninstall:dotfiles)
dotfiles reset         # uninstall + re-setup (replaces reset:dotfiles)
```

---

## 1. Why?

### Problems today

| Problem | Detail |
|---------|--------|
| **Discovery** | No single `--help` surface. Users must know about `./setup`, `rebuild`, `tuckr:reload`, `generate-machine-config`, `pnpm:global:sync`, etc. |
| **Language split** | Bootstrap is Bash (`setup`, `lib/setup/*.sh`), runtime commands are Nushell (`rebuild`, `tuckr:reload`, `generate-machine-config`). This means Nushell must be installed *before* you can even see what commands exist. |
| **Scattered scripts** | 15+ scripts live in `Configs/scripts/.local/bin/` with inconsistent naming (`rebuild`, `tuckr:reload`, `pnpm:global:sync`, `install:helix:custom`). They're discoverable only by `ls`. |
| **No interactive mode** | Commands are "fire and forget" — no way to explore groups, pick presets interactively, or get step-by-step guidance. |
| **State management** | Setup state tracking is ad-hoc (`lib/setup/state.sh`). No central state file for what's deployed, what failed, what version was last applied. |

### Why Deno?

1. **Single binary** — `deno compile` produces a self-contained executable. No runtime needed on the target machine.
2. **Cross-platform** — macOS, Linux, Windows. Same codebase.
3. **TypeScript/Type-safe** — The current bash/nushell code is fragile. TypeScript catches errors at compile time.
4. **Std library** — Built-in YAML/TOML/JSON parsing, HTTP client, file ops, prompts (`@cliffy/cli` for interactive pickers).
5. **Nix installation** — The `setup` script currently installs tuckr and nushell as temporary bootstrap dependencies. With Deno, the CLI *is* the bootstrap tool — it can compile itself to a binary and drop it in `~/.local/bin/`.
6. **Incremental migration** — The CLI can shell out to existing bash/nushell scripts during Phase 1, then port them in-place during Phase 2. Nothing breaks.

---

## 2. Proposed Command Tree

```
dotfiles
├── setup                     # Initial installation (replaces ./setup)
│   ├── [--preset PRESET]     # core | dev | workstation | ci
│   ├── [--groups GROUPS]     # comma-separated group list
│   ├── [--lite]              # CLI-focused mode
│   ├── [--skip-nix]          # skip nix installation
│   ├── [--doctor]            # preflight checks only
│   ├── [--dry-run]           # show plan, don't execute
│   ├── [--no-confirm]        # headless mode
│   ├── [--resume]            # resume from last failure
│   └── [--from TARGET]       # resume from a specific phase/group
│
├── rebuild                   # Rebuild nix + redeploy (replaces rebuild script)
│   ├── [--groups GROUPS]     # only these groups
│   ├── [--lite]              # override lite mode
│   └── [--dry-run]           # show plan without executing
│
├── reload                    # Tuckr reload all groups (replaces tuckr:reload)
│   └── [--group GROUP]       # reload a single group
│
├── doctor                    # Preflight / health checks
│   └── [--verbose]           # show all checks including passing ones
│
├── groups                    # Config group management
│   ├── list                  # list available groups
│   ├── info <GROUP>          # show group details (description, platforms, hooks, deps)
│   ├── deploy <GROUPS>       # deploy specific groups
│   ├── undeploy <GROUPS>     # remove specific groups
│   └── status                # show deployment status of all groups
│
├── machine                   # Machine.nix management
│   ├── config                 # print current machine.nix values
│   ├── set-lite <on|off>     # toggle lite mode
│   ├── set-desktop <on|off>  # toggle desktop mode
│   ├── set-always-on <on|off># toggle always-on mode
│   ├── add-preset <PRESET>   # add a machine preset (ironclaw, etc.)
│   ├── remove-preset <PRESET># remove a machine preset
│   └── regenerate             # re-run generate-machine-config
│
├── nix                       # Direct nix operations
│   ├── switch                # darwin switch or home-manager switch
│   └── profile <add|remove>  # manage nix profile packages
│
├── env                       # Environment management
│   ├── setup                  # setup:env — manage .env.dotfiles fallback
│   └── secrets [load]        # load secrets via SecretSpec + 1Password
│
├── pnpm                      # pnpm global package management
│   ├── list                   # pnpm:global:list
│   ├── sync                   # pnpm:global:sync
│   ├── add <PKG>              # pnpm:global:add
│   ├── remove <PKG>           # pnpm:global:remove
│   └── update [PKG]           # pnpm:global:update
│
├── uninstall                 # Full uninstall (replaces uninstall:dotfiles)
│   └── [--keep-nix]          # skip nix uninstallation
│
├── reset                      # Uninstall + re-setup (replaces reset:dotfiles)
│
└── version                    # Print CLI version
```

---

## 3. Migration Strategy — Three Phases

### Phase 1: Wrapper (ship fast, don't break anything)

**Goal:** Get the `dotfiles` binary installed and routing to existing scripts.

- Create a Deno CLI project at `cli/` in the repo root
- Use `@cliffy/command` for subcommands, help generation, and interactive prompts
- Each subcommand **shells out** to the existing bash/nushell scripts
- The `rebuild` command is ported natively to TypeScript (it's the highest-value target)
- Add a `Configs/scripts/.local/bin/dotfiles` symlink or wrapper that runs the compiled binary
- The `setup` script gains a step that installs the `dotfiles` binary via `nix profile add` or `deno compile`
- **Existing scripts remain untouched and functional**

### Phase 2: Port Core Commands

**Goal:** Replace bash/nushell implementations with TypeScript.

Port in priority order (by frequency of use + complexity):

1. `rebuild` — already partially ported in Phase 1
2. `setup` — the big one; break it into phases that map to subcommand steps
3. `reload` / `groups deploy` / `groups undeploy` — port tuckr interaction logic
4. `doctor` — port the preflight checks
5. `machine` — port machine.nix read/write (already in nushell nu_modules)
6. `groups list` / `groups info` — port group TOML metadata parsing

Each ported command:
- Gets unit tests in `cli/test/`
- Gets integration tests that run against the real repo structure
- Ships alongside the old script; the old script gets a deprecation notice
- The CLI detects which implementation to use (native TS or fallback script)

### Phase 3: Polish and Interactive Mode

**Goal:** Make the CLI genuinely pleasant to use.

- Interactive setup wizard (`dotfiles setup` with pickers for groups, presets)
- TUI dashboard (`dotfiles status`) showing deployment state, version tracking, and health
- Completion scripts (bash, zsh, fish, nushell)
- Auto-update mechanism (the CLI can check for new versions and self-update)
- Progressive output with spinners and progress bars
- Configuration file (`~/.config/dotfiles/config.toml`) for persistent preferences

---

## 4. Project Structure

```
cli/
├── deno.json                  # Deno config (tasks, lint, fmt)
├── deno.lock                  # Lock file
├── main.ts                   # Entry point — registers all subcommands
├── lib/
│   ├── config.ts              # Resolve dotfiles repo dir, machine.nix paths
│   ├── groups.ts              # Group discovery, metadata parsing (TOML)
│   ├── machine.ts             # machine.nix read/write/validate
│   ├── nix.ts                 # Nix profile operations, rebuild logic
│   ├── platform.ts            # OS/arch detection (macOS, Linux, etc.)
│   ├── preset.ts              # Preset definitions and group resolution
│   ├── state.ts               # Persistent state (last setup, deployed groups)
│   ├── tuckr.ts               # Tuckr binary interaction (symlink, set, add)
│   └── shell.ts               # Shell-out helpers (run external commands)
├── commands/
│   ├── setup.ts                # dotfiles setup
│   ├── rebuild.ts              # dotfiles rebuild
│   ├── reload.ts               # dotfiles reload
│   ├── doctor.ts               # dotfiles doctor
│   ├── groups.ts               # dotfiles groups (list, info, deploy, undeploy, status)
│   ├── machine.ts              # dotfiles machine (config, set-*, add-preset, ...)
│   ├── nix.ts                  # dotfiles nix (switch, profile)
│   ├── env.ts                  # dotfiles env (setup, secrets)
│   ├── pnpm.ts                 # dotfiles pnpm (list, sync, add, remove, update)
│   ├── uninstall.ts            # dotfiles uninstall
│   ├── reset.ts                # dotfiles reset
│   └── version.ts              # dotfiles version
├── test/
│   ├── commands/
│   │   └── ...                 # Command-level tests
│   └── lib/
│       └── ...                 # Library function tests
└── README.md                   # CLI-specific documentation
```

---

## 5. Key Design Decisions

### 5a. The CLI is installed *by* the project

When `./setup` runs, it:
1. Checks if `dotfiles` CLI is already installed
2. If not, compiles it from `cli/` using Deno (or downloads a pre-built binary from GitHub Releases)
3. Places it at `~/.local/bin/dotfiles`
4. Adds `dotfiles` to the `scripts` tuckr group so it stays updated

This means the CLI is a first-class managed artifact, just like `rebuild` or `generate-machine-config`.

### 5b. Shell-out during Phase 1, native during Phase 2+

During Phase 1, each command in `cli/commands/` follows this pattern:

```typescript
// commands/reload.ts (Phase 1)
export async function reload(opts: { group?: string }) {
  const script = resolveScript("tuckr:reload");
  const args = opts.group ? ["--group", opts.group] : [];
  await runCommand(script, args);
}
```

During Phase 2, this becomes:

```typescript
// commands/reload.ts (Phase 2)
export async function reload(opts: { group?: string }) {
  const groups = opts.group 
    ? [opts.group] 
    : await discoverGroups({ platform: detectPlatform() });
  for (const g of groups) {
    await tuckrDeploy(g, { force: false });
  }
}
```

### 5c. Configuration groups stay in TOML

The `Configs/*.group.toml` files remain the source of truth for group metadata. The CLI reads them directly. No migration needed.

### 5d. The `setup` script remains until Phase 2 is complete

The bootstrap scenario (fresh machine, no Nix, no Nushell, no Deno) still needs a plain bash script. `./setup` continues to work independently. Once the `dotfiles` binary is installed (by `./setup` or by Nix), all subsequent commands go through the CLI.

### 5e. State file

The CLI introduces `~/.local/share/dotfiles/state.json`:

```json
{
  "version": 1,
  "lastSetup": "2025-05-25T22:00:00Z",
  "lastRebuild": "2025-05-25T23:00:00Z",
  "preset": "workstation",
  "lite": false,
  "platform": "darwin",
  "deployedGroups": ["shell", "git", "nix", "..."],
  "failedGroups": [],
  "nixProfileVersion": "abc123",
  "homeManagerGeneration": "def456"
}
```

This replaces `lib/setup/state.sh` and the `rebuild-changes.log` in a structured, queryable format.

---

## 6. What Stays vs What Gets Replaced

| Current | CLI Command | Phase | Status |
|---------|-----------|-------|--------|
| `./setup` | `dotfiles setup` | 2 | Preserved as fallback |
| `./setup --doctor` | `dotfiles doctor` | 2 | Preserved as fallback |
| `./setup --list-groups` | `dotfiles groups list` | 2 | Preserved as fallback |
| `./setup --explain-group X` | `dotfiles groups info X` | 2 | Preserved as fallback |
| `./setup --dry-run` | `dotfiles setup --dry-run` | 2 | Preserved as fallback |
| `rebuild` (nushell) | `dotfiles rebuild` | 1 | Shell-out → native |
| `tuckr:reload` (nushell) | `dotfiles reload` | 1 | Shell-out → native |
| `generate-machine-config` (nushell) | `dotfiles machine regenerate` | 2 | Native port |
| `setup:dotfiles` (bash) | `dotfiles setup` | 2 | Preserved as fallback |
| `uninstall:dotfiles` (bash) | `dotfiles uninstall` | 2 | Native port |
| `reset:dotfiles` (bash) | `dotfiles reset` | 2 | Native port |
| `setup:env` (nushell) | `dotfiles env setup` | 2 | Native port |
| `pnpm:global:*` (nushell) | `dotfiles pnpm *` | 2 | Shell-out → native |
| `install:helix:custom` (nushell) | `dotfiles helix install` | 3 | Native port |
| `tuckr:redeploy` (nushell) | `dotfiles groups deploy --force` | 2 | Native port |
| `update:node` (nushell) | `dotfiles update node` | 3 | Native port |
| `co` (nushell) | `dotfiles co` or stays as-is | 3 | TBD |
| **NEW** | `dotfiles groups status` | 3 | New — shows what's deployed |
| **NEW** | `dotfiles groups undeploy` | 2 | New — selective removal |
| **NEW** | `dotfiles env secrets` | 2 | New — SecretSpec integration |
| **NEW** | `dotfiles machine add-preset` | 1 | Native (TOML edit) |
| **NEW** | `dotfiles machine remove-preset` | 1 | Native (TOML edit) |
| **NEW** | `dotfiles version` | 1 | New — CLI self-awareness |

---

## 7. Open Questions

1. **Deno or something else?** — Deno is the proposed runtime. Alternatives: Rust (single binary, but slower dev cycle), Go (single binary, but less ergonomic for TOML/string ops). Deno wins on dev velocity and the fact that this project already uses Nushell (another non-standard runtime).

2. **Should `dotfiles` be the binary name or `.files`?** — `dotfiles` is clearer for `--help` and tab completion. `.files` is shorter but hidden. Recommendation: binary is `dotfiles`, alias `df` for power users.

3. **How to handle the bootstrap chicken-and-egg?** — On a fresh machine with nothing installed, `./setup` (bash) still runs first. It installs Nix and Deno (via `nix profile add`), then `dotfiles` takes over. This is the same pattern as the current `rebuild` script being installed after Nix.

4. **Should the CLI be a Nix flake output?** — Yes. Add it to `Configs/nix/.config/nix/flake.nix` as a dev shell and package. `nix run .#dotfiles` works immediately for anyone with Nix.

5. **Should we keep the nushell nu_modules?** — During Phase 1-2, yes. During Phase 2, the TypeScript port replaces them. After Phase 2, the modules can be deprecated.

6. **Naming: `dotfiles groups deploy` vs `dotfiles deploy`?** — Keeping `groups` as a namespace avoids clashes and makes the tree cleaner. But `dotfiles deploy` could be a shortcut alias.

7. **Interactive TUI or just CLI?** — Phase 1-2: CLI only. Phase 3: Add interactive mode with `@cliffy/prompt` (select, confirm, etc.) and optionally a TUI dashboard.

---

## 8. Next Steps

1. **Scaffold the `cli/` project** — `deno.json`, directory structure, `main.ts` with help output
2. **Implement `dotfiles version`** — reads version from `deno.json` or git tag
3. **Implement `dotfiles rebuild`** — shell out to the existing nushell rebuild script (Phase 1)
4. **Implement `dotfiles reload`** — shell out to `tuckr:reload` (Phase 1)
5. **Wire `dotfiles` binary into the Nix flake** — so `nix profile add` installs it
6. **Update `./setup` to install `dotfiles` alongside tuckr/nushell** — so it's available after bootstrap
7. **Add `dotfiles` to the `scripts` tuckr group** — so it stays updated via tuckr

These 7 steps constitute Phase 1. Phase 2 starts once the CLI is installed and functional.