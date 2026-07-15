# secrets.nu — Monosecret + 1Password secret injection
#
# Secrets are declared in ~/monosecret.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   msr --reason <text> <command>   Run a command with secrets injected ephemerally
#   msload --reason <text>          Load all declared secrets into the current shell session

def require-reason [command: string, reason] {
    let audit_reason = $reason | default "" | str trim
    if ($audit_reason | is-empty) {
        error make {msg: $"($command): --reason <text> is required"}
    }
    $audit_reason
}

# Run a command with all secrets injected ephemerally. `--wrapped` allows flags
# belonging to the child command to pass through unchanged.
#   msr --reason "publish release" mc step:publish-release --from-ref=HEAD
#   msr --reason "run Codex" codex --profile mimo
export def --wrapped msr [--reason(-r): string, ...command: string] {
    let audit_reason = (require-reason "msr" $reason)
    if ($command | is-empty) {
        error make {msg: "msr: a command is required after --reason <text>"}
    }

    ^monosecret -f $"($env.HOME)/monosecret.toml" --reason $audit_reason run -- ...$command
}

# Load all declared secrets into the current Nushell session.
# Prefer `msr --reason <text> <command>` unless you intentionally want secrets resident in the shell.
export def --env msload [--reason(-r): string] {
    let audit_reason = (require-reason "msload" $reason)
    let monosecret_file = $"($env.HOME)/monosecret.toml"
    if not ($monosecret_file | path exists) {
        error make {msg: $"msload: missing ($monosecret_file)"}
    }
    let keys = (
        open $monosecret_file | get profiles.default | columns | where {|key| $key != "defaults" }
    )
    if ($keys | is-empty) {
        error make {msg: $"msload: no secrets found in ($monosecret_file)"}
    }
    let env_vars = (
        ^monosecret -f $monosecret_file --reason $audit_reason run -- env | lines | each { |line|
            let idx = $line | str index-of "="
            if $idx == -1 { return null }

            let key = $line | str substring 0..<$idx
            if $key not-in $keys { return null }

            let value = $line | str substring ($idx + 1)..
            { $key: $value }
        } | where {|item| $item != null } | reduce --fold {} {|item, acc| $acc | merge $item }
    )
    if ($env_vars | is-not-empty) {
        $env_vars | load-env
    }
}
