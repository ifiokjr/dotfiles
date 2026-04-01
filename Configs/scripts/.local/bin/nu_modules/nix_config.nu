# nix_config.nu - Nix configuration path resolution
#
# Shared utilities for resolving nix config paths and parsing machine.nix.
# Usage: use nu_modules/nix_config.nu
# Resolve the actual nix config directory (follows symlinks)
export def config-dir [] {
    let nix_config_link = $"($env.HOME)/.config/nix"
    $nix_config_link | path expand
}
# Directory to pass to --flake (resolved so Nix sees the real flake, not a symlink).
# When flake.nix is a Tuckr symlink, Nix can mis-resolve it and produce invalid paths;
# using the resolved directory avoids that.
export def flake-dir [] {
    let link_dir = (config-dir)
    let flake_nix = $"($link_dir)/flake.nix"
    if ($flake_nix | path exists) {
        # path expand resolves the symlink; dirname gives the flake root
        ($flake_nix | path expand | path dirname)
    } else {
        # CI/workflow checkouts may run without ~/.config/nix symlinks deployed.
        # In that case, fall back to the flake path inside the checked out repo.
        let repo_root = try {
            ^git rev-parse --show-toplevel | str trim
        } catch { "" }
        if ($repo_root | is-not-empty) {
            let repo_flake = $"($repo_root)/Configs/nix/.config/nix/flake.nix"
            if ($repo_flake | path exists) {
                ($repo_flake | path expand | path dirname)
            } else {
                $link_dir
            }
        } else {
            $link_dir
        }
    }
}
# Path to machine.nix
export def machine-config-path [] { $"(config-dir)/machine.nix" }
# Set the machine.nix lite mode flag (inserts the field if missing).
export def set-lite-mode [value: bool, --path(-p): string] {
    let target_path = ($path | default (machine-config-path))
    if not ($target_path | path exists) {
        error make {
            msg: $"machine.nix not found at: ($target_path)"
        }
    }
    let content = (open $target_path --raw)
    let lite_value = (if $value { "true" } else { "false" })
    let lite_line = $"  lite = ($lite_value);"
    let updated = if ($content | str contains "lite =") {
        $content | str replace --regex '(?m)^\s*lite\s*=\s*(true|false);\s*$' $lite_line
    } else {
        let with_lite = $"\n  # Lite profile \(CLI-focused, skips GUI-heavy applications\)\n($lite_line)\n}"
        $content | str replace --regex '\n\}\s*$' $with_lite
    }
    $updated | save -f $target_path
}
# Parse machine.nix and return {username, system, hostname} record.
# machine.nix is a simple Nix attrset (not a module), so we extract
# values with regex rather than invoking the nix evaluator.
export def parse-machine-config [] {
    let path = (machine-config-path)
    if not ($path | path exists) {
        error make {
            msg: $"machine.nix not found at: ($path)"
        }
    }
    let content = (open $path --raw)
    # `parse --regex` returns a table; `.get capture0.0` grabs the first match
    let username = ($content | parse --regex 'username = "([^"]+)"' | get capture0.0)
    let system = ($content | parse --regex 'system = "([^"]+)"' | get capture0.0)
    # hostname is optional — older machine.nix files may not have it
    let hostname = try {
        $content | parse --regex 'hostname = "([^"]+)"' | get capture0.0
    } catch { "" }
    # lite is optional — older machine.nix files may not have it
    let lite = try { (($content | parse --regex 'lite\s*=\s*(true|false);' | get capture0.0) == "true") } catch { false }
    {
        username: $username
        system: $system
        hostname: $hostname
        lite: $lite
    }
}
