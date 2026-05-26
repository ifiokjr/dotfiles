# Dotfiles CLI

Unified CLI for managing dotfiles — setup, rebuild, reload, doctor, and more.

## Quick Start

```bash
# Run directly with Deno
cd cli && deno task dev --help

# Or compile to a standalone binary
cd cli && deno task compile:dev
./dotfiles --help
```

## Development

```bash
cd cli

# Run in dev mode (auto-reloads on changes)
deno task dev --help

# Type check
deno task check

# Run tests
deno task test

# Lint
deno task lint

# Format
deno task fmt

# Compile the binary
deno task compile
```

## Architecture

- **Phase 1 (current):** All commands shell out to existing bash/nushell scripts
- **Phase 2 (future):** Core commands reimplemented natively in TypeScript
- **Phase 3 (future):** Interactive mode, TUI dashboard, completions

See `docs/proposals/dotfiles-cli.md` for the full proposal and migration plan.