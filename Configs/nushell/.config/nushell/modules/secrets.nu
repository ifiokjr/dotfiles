# secrets.nu — Monosecret + 1Password secret injection
#
# Secrets are declared in ~/monosecret.toml and resolved at runtime from a
# 1Password vault. Never written to disk in plaintext.
#
# Usage:
#   ssr <command>   Run a command with secrets injected ephemerally
#   ssload          Load all declared secrets into the current shell session
# Run a command with all secrets injected ephemerally.
# Alias expands before Nushell's parser, so flags pass through correctly.
#   ssr mc step:publish-release --from-ref=HEAD
#   ssr codex --profile mimo
export alias ssr = monosecret -f $"($env.HOME)/monosecret.toml" --reason "dotfiles secret injection" run --

# Load all declared secrets into the current Nushell session.
# Prefer `ssr <command>` unless you intentionally want secrets resident in the shell.
export def --env ssload [] {
    let monosecret_file = $"($env.HOME)/monosecret.toml"
    if not ($monosecret_file | path exists) {
        error make {msg: $"ssload: missing ($monosecret_file)"}
    }
    let keys = (
        open $monosecret_file | get profiles.default | columns | where {|key| $key != "defaults" }
    )
    if ($keys | is-empty) {
        error make {msg: $"ssload: no secrets found in ($monosecret_file)"}
    }
    let env_vars = (
        ^monosecret -f $monosecret_file --reason "dotfiles shell secret load" run -- env | lines | each { |line|
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
