# secrets.nu — SecretSpec + 1Password secret injection
#
# Secrets are declared in ~/secretspec.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ssr <command>   Run a command with secrets injected ephemerally
#   ssload          Load all declared secrets into the current shell session
# Run a command with all secrets injected ephemerally.
export def ssr [...args] { ^secretspec run -f $"($env.HOME)/secretspec.toml" -- ...$args }
# Load all declared secrets into the current Nushell session.
# Prefer `ssr <command>` unless you intentionally want secrets resident in the shell.
export def --env ssload [] {
    let secretspec_file = $"($env.HOME)/secretspec.toml"
    if not ($secretspec_file | path exists) {
        error make {
            msg: $"ssload: missing ($secretspec_file)"
        }
    }
    let keys = (
        open $secretspec_file | get profiles.default | columns | where { |key| $key != "defaults" }
    )
    if ($keys | is-empty) {
        error make {
            msg: $"ssload: no secrets found in ($secretspec_file)"
        }
    }
    let env_vars = (
        ^secretspec run -f $secretspec_file -- env | lines | each { |line|
            let idx = ($line | str index-of "=")
            if $idx == -1 { return null }

            let key = ($line | str substring 0..<$idx)
            if $key not-in $keys { return null }

            let value = ($line | str substring ($idx + 1)..)
            { $key: $value }
        } | where { |item| $item != null } | reduce --fold {} { |item, acc| $acc | merge $item }
    )
    if ($env_vars | is-not-empty) {
        $env_vars | load-env
    }
}
