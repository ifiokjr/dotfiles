# Dotfiles CLI

Unified CLI for managing dotfiles — setup, rebuild, reload, doctor, and more.

After a rebuild, the binary is auto-compiled and installed to `~/.local/bin/dotfiles` with a `dot` symlink alias for quick access.

```bash
dot --help          # show all commands
dot help groups          # detailed help for a subcommand
dot groups list          # via the shorter alias
dot reload --force  # force overwrite existing symlinks
```

## Quick Start

```bash
# Run directly with Deno
cd cli && deno task run -- --help

# Or compile to a standalone binary (~76MB)
cd cli && deno task compile:dev
./dot --help
```

## Development

```bash
cd cli

# Run in dev mode (auto-reloads on changes)
deno task dev -- --help

# Type checking
deno task check

# Linting (oxlint + deno lint)
deno task lint

# Auto-format (uses dprint for all files including cli/)
# Run from repo root — dprint is the single formatter for the entire repo
dprint fmt

# Run all checks (typecheck + oxlint + deno lint)
deno task check:all

# Run tests
deno task test

# Compile the binary (production)
deno task compile
```

## Alias

The `dotfiles` binary also installs a `dot` symlink alias:

- `dotfiles` — full command name
- `dot` — short alias (~3 chars, doesn't conflict with existing Unix commands like `df`)

Both point to the same compiled binary.

## Tooling

| Tool          | Purpose                                                            | Command                 |
| ------------- | ------------------------------------------------------------------ | ----------------------- |
| **Deno**      | Runtime, type checking (`deno check`)                              | `deno task check`       |
| **oxlint**    | Fast JavaScript/TypeScript linting (via `npm:oxlint`)              | `deno task lint:oxlint` |
| **deno lint** | Deno's built-in linter (catches what oxlint misses)                | `deno task lint:deno`   |
| **dprint**    | Formatting for the entire repo (including `cli/` TypeScript files) | `dprint fmt`            |

> **Note:** Formatting is handled exclusively by dprint (runs from repo root). The `cli/` directory uses tabs and the same dprint typescript plugin as the rest of the repo. There is no separate `deno fmt` step.

### Full verification pipeline

```bash
# From repo root:
dprint check --config Configs/dprint/dprint.json   # format check (all files)
cd cli && deno task check:all                        # typecheck + lint
```

## Architecture

- **Phase 1:** CLI wrapper around existing bash/nushell scripts
- **Phase 2 (current):** Port low-risk command logic natively when it improves readability and testability
- **Phase 3 (future):** Interactive mode, TUI dashboard, completions

`dot setup` intentionally remains a thin wrapper around the existing setup script. Setup is a system-level bootstrapper that installs Nix, creates symlinks, and applies host configuration, so keeping the battle-tested shell script avoids bloating the CLI with risky duplicate orchestration.

See `docs/proposals/dotfiles-cli.md` for the full proposal and migration plan.
