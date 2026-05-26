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

# Format check
deno task fmt:check

# Auto-format
deno task fmt

# Run all checks (typecheck + oxlint + deno lint + format check)
deno task check:all

# Run tests
deno task test

# Compile the binary (production)
deno task compile
```

## Tooling

| Tool          | Purpose                                                     | Command                 |
| ------------- | ----------------------------------------------------------- | ----------------------- |
| **Deno**      | Runtime, type checking (`deno check`)                       | `deno task check`       |
| **oxlint**    | Fast JavaScript/TypeScript linting (via `npm:oxlint`)       | `deno task lint:oxlint` |
| **deno lint** | Deno's built-in linter (catches what oxlint misses)         | `deno task lint:deno`   |
| **deno fmt**  | Code formatting (2-space indent, double quotes, semicolons) | `deno task fmt`         |
| **dprint**    | Formats the rest of the repo (not CLI files)                | `dprint fmt`            |

### Full verification pipeline

```bash
deno task check:all
```

This runs all four checks in sequence: type check → oxlint → deno lint → format
check.

## Architecture

- **Phase 1 (current):** All commands shell out to existing bash/nushell scripts
- **Phase 2 (future):** Core commands reimplemented natively in TypeScript
- **Phase 3 (future):** Interactive mode, TUI dashboard, completions

See `docs/proposals/dotfiles-cli.md` for the full proposal and migration plan.
