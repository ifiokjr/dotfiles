# CLI Dependency Security Analysis

## Dependencies

All dependencies are resolved via JSR (Deno's package registry) with integrity
hashes pinned in `deno.lock`.

### Runtime Dependencies

| Package | Version | Source | Risk |
|---------|---------|--------|------|
| `@cliffy/command` | 1.1.0 | JSR | Low — mature CLI framework, MIT licensed, maintained by @c4spar |
| `@cliffy/prompt` | 1.1.0 | JSR | Low — only used for future interactive features |
| `@std/fs` | 1.0.23 | JSR | Minimal — Deno official stdlib, read/exists/walk |
| `@std/path` | 1.1.4 | JSR | Minimal — Deno official stdlib, path manipulation |
| `@std/toml` | 1.0.0 | JSR | Minimal — Deno official stdlib, TOML parsing |
| `@std/fmt` | 1.0.10 | JSR | Minimal — Deno official stdlib, ANSI colors |

### Dev Dependencies

| Package | Version | Source | Risk |
|---------|---------|--------|------|
| `oxlint` | 1.67.0 | npm | Low — linter only, not in compiled binary |

### Key Security Points

1. **No network dependencies at runtime.** The compiled binary embeds only local
   TypeScript files. No code is fetched at runtime.

2. **Integrity pins.** `deno.lock` pins every JSR module to a SHA-256 integrity
   hash. Tampering with any dependency would cause a lockfile mismatch.

3. **Small attack surface.** The CLI shells out to existing scripts (tuckr,
   nushell, secretspec) using `Deno.Command`. It does not accept arbitrary
   input over the network.

4. **No known CVEs** for any dependency. The Deno runtime CVE-2025-61787
   (Windows batch file command injection) is fixed in Deno >= 2.2.15; our
   runtime is 2.8.0.

5. **Deno permissions.** The binary is compiled with `--allow-all`. This is
   acceptable because the CLI is a local management tool that needs full
   filesystem access to manage dotfiles. In Phase 2, we should evaluate
   narrowing permissions.

6. **oxlint is dev-only.** It runs during `deno task check:all` and CI but is
   not embedded in the compiled binary.