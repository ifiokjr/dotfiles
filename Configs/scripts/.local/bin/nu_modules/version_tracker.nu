# version_tracker.nu - Track package version changes across rebuilds
#
# Captures "before" and "after" snapshots of installed packages and computes diffs.
# Supports Nix (home-manager + nix-darwin closures), pnpm globals, and Homebrew.
# ─────────────────────────────────────────────────────────────────────────────
# Nix profiles
# ─────────────────────────────────────────────────────────────────────────────
# Resolve a symlink to its final store path.
def resolve-store-path [profile: string] {
    if ($profile | path exists) {
        (^readlink -f $profile | str trim)
    } else {
        null
    }
}
# Capture the current home-manager activation store path.
export def capture-hm-profile [] { resolve-store-path $"($env.HOME)/.local/state/nix/profiles/home-manager" }
# Capture the current nix-darwin system store path.
export def capture-darwin-profile [] { resolve-store-path "/nix/var/nix/profiles/system" }
# Run `nix store diff-closures` between two store paths.
# Returns the raw text output (each line is one changed derivation).
export def diff-nix-closures [old_path: string, new_path: string] {
    if ($old_path | is-empty) or ($new_path | is-empty) {
        return null
    }
    let result = (^nix store diff-closures $old_path $new_path | complete)
    if $result.exit_code != 0 {
        return null
    }
    $result.stdout | lines | where $it != ""
}
# ─────────────────────────────────────────────────────────────────────────────
# pnpm globals
# ─────────────────────────────────────────────────────────────────────────────
# Return a list of {name, version} records for managed pnpm global project packages.
export def capture-pnpm-globals [] {
    if (which pnpm | is-empty) { return null }
    let runtime_dir = (
        $env.XDG_DATA_HOME?
        | default ($env.HOME | path join ".local/share")
        | path join "pnpm-global"
    )
    if not ($runtime_dir | path join "package.json" | path exists) { return null }
    let result = (
        ^bash -lc 'cd "${XDG_DATA_HOME:-$HOME/.local/share}/pnpm-global" && pnpm list --json'
        | complete
    )
    if $result.exit_code != 0 { return null }
    let parsed = try {
        $result.stdout | from json
    } catch { return null }
    if ($parsed | is-empty) { return null }
    let root = if ($parsed | describe | str contains "list") {
        $parsed | get 0
    } else {
        $parsed
    }
    let deps = try {
        $root | get --optional dependencies
    } catch { return null }
    let deps_type = try {
        $deps | describe
    } catch { "nothing" }
    if ($deps_type | str contains "nothing") or (not ($deps_type | str starts-with "record")) {
        return null
    }
    $deps | items {|name, info| { name: $name, version: ($info | get --optional version | default "") } }
}
# ─────────────────────────────────────────────────────────────────────────────
# Homebrew
# ─────────────────────────────────────────────────────────────────────────────
# Return a list of {name, version} records for installed Homebrew formulae/casks.
export def capture-brew-packages [] {
    if (which brew | is-empty) { return null }
    let result = (^brew list --versions | complete)
    if $result.exit_code != 0 { return null }
    $result.stdout | lines | where $it != "" | parse "{name} {version}" | default "" version
}
# ─────────────────────────────────────────────────────────────────────────────
# Generic diff helpers
# ─────────────────────────────────────────────────────────────────────────────
# Diff two lists of {name, version} records.
# Returns {added: [...], removed: [...], changed: [...]} where each item is:
#   {name, old, new}
export def diff-package-lists [old: list<any>, new: list<any>] {
    let old_map = (
        $old
        | default []
        | reduce -f {} {|it, acc| $acc | insert $it.name $it.version }
    )
    let new_map = (
        $new
        | default []
        | reduce -f {} {|it, acc| $acc | insert $it.name $it.version }
    )
    let added = (
        $new_map
        | items {|name, ver| { name: $name, old: "", new: $ver } }
        | where {|it| not ($it.name in ($old_map | columns)) }
    )
    let removed = (
        $old_map
        | items {|name, ver| { name: $name, old: $ver, new: "" } }
        | where {|it| not ($it.name in ($new_map | columns)) }
    )
    let changed = (
        $new_map
        | items {|name, ver| { name: $name, old: ($old_map | get --optional $name | default ""), new: $ver } }
        | where {|it| ($it.old != "") and ($it.old != $it.new) }
    )
    {added: $added, removed: $removed, changed: $changed}
}
# ─────────────────────────────────────────────────────────────────────────────
# Pretty-print helpers
# ─────────────────────────────────────────────────────────────────────────────
# Print a package diff returned by diff-package-lists.
export def print-package-diff [diff: record, title: string] {
    let added_count = $diff.added | length
    let removed_count = $diff.removed | length
    let changed_count = $diff.changed | length
    let total = $added_count + $removed_count + $changed_count
    if $total == 0 { return }
    header $title
    for pkg in $diff.added { success $"  + ($pkg.name) ($pkg.new)" }
    for pkg in $diff.removed { err $"  - ($pkg.name) ($pkg.old)" }
    for pkg in $diff.changed { info $"  ~ ($pkg.name): ($pkg.old) → ($pkg.new)" }
}
# Print a raw Nix closure diff (list of strings). Filters out noise lines.
export def print-nix-diff [lines: list<string>, title: string] {
    if ($lines | is-empty) { return }
    # Filter out empty lines and lines with no actual change indicator
    let meaningful = (
        $lines
        | where {|it| ($it | str contains "→") or ($it | str contains "+") or ($it | str contains "-") }
    )
    if ($meaningful | is-empty) { return }
    header $title
    for line in $meaningful {
        if ($line | str contains "→") {
            info $"  ($line)"
        } else if ($line | str starts-with "+") {
            success $"  ($line)"
        } else if ($line | str starts-with "-") {
            err $"  ($line)"
        } else {
            print $"  ($line)"
        }
    }
}
# ─────────────────────────────────────────────────────────────────────────────
# Persistent log
# ─────────────────────────────────────────────────────────────────────────────
# Append a rebuild summary to a persistent log file.
# `sections` is a list of strings (already formatted).
export def log-rebuild-summary [sections: list<string>, --log-file: string] {
    let file = if ($log_file | is-empty) {
        $"($env.HOME)/.local/share/dotfiles/rebuild-changes.log"
    } else {
        $log_file
    }
    mkdir ($file | path dirname)
    let timestamp = date now | format date "%Y-%m-%d %H:%M:%S"
    let sep = "═══════════════════════════════════════════════════════════════════════════════"
    let lines = [
        $sep
        $"Rebuild Summary — ($timestamp)"
        $sep
        ""
    ] | append $sections | append ["", ""]
    $lines | str join "\n" | save --append $file
}
