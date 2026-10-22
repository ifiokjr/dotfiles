# CLI Dependency Security Analysis

## Dependencies

All dependencies are resolved via JSR (Deno's package registry) with integrity hashes pinned in `deno.lock`.

### Runtime Dependencies

| Package           | Version | Source | Risk                                                            |
| ----------------- | ------- | ------ | --------------------------------------------------------------- |
| `@cliffy/command` | 1.1.0   | JSR    | Low — mature CLI framework, MIT licensed, maintained by @c4spar |
| `@std/fs`         | 1.0.23  | JSR    | Minimal — Deno official stdlib, read/exists/walk                |
| `@std/path`       | 1.1.4   | JSR    | Minimal — Deno official stdlib, path manipulation               |
| `@std/toml`       | 1.0.0   | JSR    | Minimal — Deno official stdlib, TOML parsing                    |
| `@std/fmt`        | 1.0.10  | JSR    | Minimal — Deno official stdlib, ANSI colors                     |

### Dev Dependencies

| Package  | Version | Source | Risk                                      |
| -------- | ------- | ------ | ----------------------------------------- |
| `oxlint` | 1.67.0  | npm    | Low — linter only, not in compiled binary |

### Key Security Points

1. **Runtime network access is limited and pinned to known hosts.** The
   compiled binary itself embeds only local TypeScript files, but
   `lib/managed_skills.ts` fetches from `api.github.com` and
   `codeload.github.com` during the explicit `dot rebuild --update` flow
   (managed-skill sync). Everything else is local.

2. **Integrity pins.** `deno.lock` pins every JSR module to a SHA-256 integrity
   hash. Tampering with any dependency would cause a lockfile mismatch.

3. **Small attack surface.** The CLI shells out to existing scripts (tuckr,
   nushell, monosecret) using array-form `Deno.Command` (no shell string
   interpolation of external input). It does not accept arbitrary input over
   the network.

4. **No known CVEs** for any dependency. The Deno runtime CVE-2025-61787
   (Windows batch file command injection) is fixed in Deno >= 2.2.15; our
   runtime is 2.8.0.

5. **Deno permissions.** The binary is compiled with `--allow-all`. This is
   accepted because the CLI is a local management tool that needs full
   filesystem access to manage dotfiles; narrowing the permission set remains
   possible future work.

6. **Privileged execution.** Commands that run under `sudo` resolve their
   target binary from root-owned directories only (`privilegedPathEnv()` in
   `lib/config.ts`, plus `secure_path` in darwin.nix), so a shim planted in a
   user-writable bin directory cannot execute as root via `dot rebuild`.

7. **oxlint is dev-only.** It runs during `deno task check:all` and CI but is
   not embedded in the compiled binary.
