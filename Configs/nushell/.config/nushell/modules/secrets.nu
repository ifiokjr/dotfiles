# secrets.nu — SecretSpec + 1Password secret injection
#
# Secrets are declared in ~/secretspec.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ssr <command>   Run a command with secrets injected ephemerally
# Run a command with all secrets injected ephemerally
export def ssr [...args] { ^secretspec run -f $"($env.HOME)/secretspec.toml" -- ...$args }
