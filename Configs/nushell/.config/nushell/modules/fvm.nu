# fvm.nu — FVM per-project Flutter/Dart auto-switching with allow-gate security
#
# Security model (like direnv's `direnv allow`):
#   Auto-loading only activates for directories explicitly allowed by the user.
#   This prevents malicious `.fvmrc` files from injecting binaries via PATH.
#
# Commands:
#   fvm-allow   — Trust the current project directory for FVM auto-loading
#   fvm-deny    — Revoke trust for the current (or specified) directory
#   fvm-allowed — List all trusted directories
#
# The PWD hook runs on every directory change:
#   1. If fvm is not installed → skip
#   2. If `.fvmrc` is absent    → clean up any stale entries, skip
#   3. If directory is not allowed → skip (with hint to run `fvm-allow`)
#   4. Remove any previous `.fvm/flutter_sdk/bin` from PATH
#   5. Prepend the current project's `.fvm/flutter_sdk/bin` to PATH

# Path to the allow-list file. One absolute directory path per line.
def fvm-allow-file [] {
    $"($env.HOME)/.config/fvm/allowed-dirs"
}

# Add the current directory (or a given path) to the FVM allow list.
# Immediately activates the project's fvm bin on PATH.
export def --env fvm-allow [
    dir?: path  # Directory to allow (default: current directory)
] {
    let target = ($dir | default $env.PWD | path expand)
    if not (($target | path join '.fvmrc') | path exists) {
        print $"(ansi yellow)No .fvmrc found in ($target)(ansi reset)"
        return
    }
    let file = (fvm-allow-file)
    let existing = if ($file | path exists) { open $file | lines } else { [] }
    if ($existing | any {|d| $d == $target }) {
        print $"(ansi green)Already allowed:(ansi reset) ($target)"
    } else {
        let updated = ($existing | append $target)
        mkdir ($file | path dirname)
        $updated | str join "\n" | save --force $file
        print $"(ansi green)Allowed FVM auto-load for:(ansi reset) ($target)"
    }
    # Activate immediately — no need to cd out and back in
    # Per-project fvm uses `.fvm/flutter_sdk/bin`; global uses `~/fvm/default/bin`
    let fvm_bin = ($target | path join '.fvm/flutter_sdk/bin')
    $env.PATH = ($env.PATH | where {|p| not ($p | str contains '/.fvm/flutter_sdk/bin') })
    if ($fvm_bin | path exists) {
        $env.PATH = ($env.PATH | prepend $fvm_bin)
        print $"(ansi green)Activated:(ansi reset) ($fvm_bin) is on PATH"
    } else {
        print $"(ansi yellow)fvm bin not found at ($fvm_bin) — run `fvm use` first(ansi reset)"
    }
}

# Remove the current directory (or a given path) from the FVM allow list
# and strip its bin from PATH.
export def --env fvm-deny [
    dir?: path  # Directory to deny (default: current directory)
] {
    let target = ($dir | default $env.PWD | path expand)
    let file = (fvm-allow-file)
    let existing = if ($file | path exists) { open $file | lines } else { [] }
    if not ($existing | any {|d| $d == $target }) {
        print $"(ansi yellow)Not in allow list:(ansi reset) ($target)"
        return
    }
    let updated = ($existing | where {|d| $d != $target })
    $updated | str join "\n" | save --force $file
    # Remove matching fvm bin from PATH
    $env.PATH = ($env.PATH | where {|p| not ($p | str contains '/.fvm/flutter_sdk/bin') })
    print $"(ansi red)Denied FVM auto-load for:(ansi reset) ($target)"
}

# List all directories trusted for FVM auto-loading.
export def fvm-allowed [] {
    let file = (fvm-allow-file)
    if not ($file | path exists) { return }
    let dirs = (open $file | lines | where {|d| $d | is-not-empty })
    if ($dirs | is-empty) { return }
    print $"(ansi cyan)FVM allowed directories:(ansi reset)"
    $dirs | each {|d|
        let has_rc = (($d | path join '.fvmrc') | path exists)
        let marker = if $has_rc { "(ansi green)✓(ansi reset)" } else { "(ansi yellow)✗ no .fvmrc(ansi reset)" }
        print $"  ($marker) ($d)"
    }
}

# Internal: check if a directory is in the allow list.
def fvm-is-allowed [dir: path] {
    let file = (fvm-allow-file)
    if not ($file | path exists) { return false }
    let dirs = (open $file | lines | where {|d| $d | is-not-empty })
    $dirs | any {|d| $d == $dir }
}

# Internal: the auto-activate function called from the PWD hook.
# Removes any existing `.fvm/flutter_sdk/bin` from PATH, then prepends
# the current project's if `.fvmrc` exists and the directory is allowed.
# Prints a hint when `.fvmrc` is found but the directory isn't allowed yet.
export def --env fvm-auto-activate [] {
    # Skip entirely if fvm is not installed
    if (which fvm | is-empty) { return }

    if not ('.fvmrc' | path exists) {
        # Leaving a project directory — clean up any stale fvm bin entries
        $env.PATH = ($env.PATH | where {|p| not ($p | str contains '/.fvm/flutter_sdk/bin') })
        return
    }

    let dir = $env.PWD | path expand

    # Security gate: must be explicitly allowed
    if not (fvm-is-allowed $dir) {
        # Only show the hint once per directory per session by tracking in an env var
        let hint_var = "FVM_ALLOW_HINT_SHOWN"
        let shown_dirs = $env | get -o $hint_var | default []
        if not ($shown_dirs | any {|d| $d == $dir }) {
            print $"(ansi yellow)fvm: .fvmrc found — run (ansi yellow_bold)fvm-allow(ansi yellow) to trust this project(ansi reset)"
            $env.FVM_ALLOW_HINT_SHOWN = ($shown_dirs | append $dir)
        }
        return
    }

    let fvm_bin = ($dir | path join '.fvm/flutter_sdk/bin')
    if not ($fvm_bin | path exists) {
        let debug = $env | get -o DOTFILES_DEBUG | is-not-empty
        if $debug {
            print $"(ansi yellow)fvm: .fvm/flutter_sdk/bin not found — run `fvm use` in the project first(ansi reset)"
        }
        return
    }

    # Per-project fvm uses `.fvm/flutter_sdk/bin`; global uses `~/fvm/default/bin`
    let fvm_bin = ($dir | path join '.fvm/flutter_sdk/bin')
    if not ($fvm_bin | path exists) {
        let debug = $env | get -o DOTFILES_DEBUG | is-not-empty
        if $debug {
            print $"(ansi yellow)fvm: .fvm/flutter_sdk/bin not found — run `fvm use` in the project first(ansi reset)"
        }
        return
    }
    # Remove any previous .fvm/flutter_sdk/bin entries to avoid PATH pollution
    $env.PATH = ($env.PATH | where {|p| not ($p | str contains '/.fvm/flutter_sdk/bin') })
    # Prepend the project's fvm bin
    $env.PATH = ($env.PATH | prepend $fvm_bin)
}