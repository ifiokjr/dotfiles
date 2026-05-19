# secrets.nu — SecretSpec + 1Password secret injection
#
# Replaces the old .env.dotfiles loader. Secrets are resolved at runtime
# from a 1Password vault via secretspec and never written to disk.
#
# Usage:
#   ssr <command>   Run a command with secrets injected ephemerally
#   ssload          Load all secrets into the current shell session
# Run a command with secrets injected ephemerally
export def ssr [...args] { ^secretspec run -f $"($env.HOME)/secretspec.toml" -- ...$args }
# Load all secrets into the current shell (use sparingly)
export def --env ssload [] {
    # Fallback to .env.dotfiles if secretspec fails or isn't configured
    let secrets_file = $"($env.HOME)/.env.dotfiles"
    let ss_file = $"($env.HOME)/secretspec.toml"
    if ($ss_file | path exists) {
        try {
            let output = (^secretspec run -f $ss_file -- env)
            $output | lines | parse "{key}={value}" | transpose -r -d | load-env
            return
        }
    }
    # Fallback: load from .env.dotfiles if it exists
    if ($secrets_file | path exists) {
        let env_vars = (open $secrets_file | lines | where { |line|
                let trimmed = ($line | str trim)
                ($trimmed | is-not-empty) and (not ($trimmed | str starts-with "#"))
            } | each { |line|
                let eq_pos = ($line | str index-of "=")
                if ($eq_pos == -1) { return null }
                let key = ($line | str substring 0..<$eq_pos | str trim)
                let value = ($line
                    | str substring ($eq_pos + 1)..
                    | str trim
                    | str replace -r '^"(.*)"$' '$1'
                    | str replace -r "^'(.*)'$" '$1')
                { $key: $value }
            } | where { $in != null } | reduce --fold {} { |it, acc| $acc | merge $it })
        if ($env_vars | is-not-empty) {
            $env_vars | load-env
        }
    }
}
