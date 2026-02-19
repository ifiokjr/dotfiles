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
        $link_dir
    }
}

# Path to machine.nix
export def machine-config-path [] { $"(config-dir)/machine.nix" }
# Parse machine.nix and return {username, system, hostname} record.
# machine.nix is a simple Nix attrset (not a module), so we extract
# values with regex rather than invoking the nix evaluator.
export def parse-machine-config [] {
    let path = (machine-config-path)
    if not ($path | path exists) { error make {
        msg: $"machine.nix not found at: ($path)"
    } }
    let content = (open $path --raw)
    # `parse --regex` returns a table; `.get capture0.0` grabs the first match
    let username = ($content | parse --regex 'username = "([^"]+)"' | get capture0.0)
    let system = ($content | parse --regex 'system = "([^"]+)"' | get capture0.0)
    # hostname is optional — older machine.nix files may not have it
    let hostname = try {
        $content | parse --regex 'hostname = "([^"]+)"' | get capture0.0
    } catch { "" }
    {
        username: $username
        system: $system
        hostname: $hostname
    }
}
