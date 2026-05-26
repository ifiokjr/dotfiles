# Dotfiles CLI

Unified CLI for managing dotfiles — setup, rebuild, reload, doctor, and more.

## Quick Start

```bash
# Run directly with Deno
cd cli && deno task run -- --help

# Or compile to a standalone binary (~76MB)
cd cli && deno task compile:dev
./dotfiles --help
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

- **Phase 1 (current):** All commands shell out to existing bash/nushell scripts
- **Phase 2 (future):** Core commands reimplemented natively in TypeScript
- **Phase 3 (future):** Interactive mode, TUI dashboard, completions

See `docs/proposals/dotfiles-cli.md` for the full proposal and migration plan.
