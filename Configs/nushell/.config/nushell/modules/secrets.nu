# secrets.nu — SecretSpec + 1Password secret injection
#
# Replaces the old .env.dotfiles loader. Secrets are resolved at runtime
# from a 1Password vault via secretspec and never written to disk.
#
# Usage:
#   ssr <command>   Run a command with secrets injected ephemerally
#   ssload          Load all secrets into the current shell session

# Run a command with secrets injected ephemerally
export def ssr [...args] {
    ^secretspec run -f $"($env.HOME)/secretspec.toml" -- ...$args
}

# Load all secrets into the current shell (use sparingly)
export def --env ssload [] {
    let output = (^secretspec run -f $"($env.HOME)/secretspec.toml" -- env)
    $output
    | lines
    | parse "{key}={value}"
    | transpose -r -d
    | load-env
}
