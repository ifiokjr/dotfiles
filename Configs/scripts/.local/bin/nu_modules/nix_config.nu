# nix_config.nu - Nix configuration path resolution
#
# Shared utilities for resolving nix config paths and parsing machine.nix.
# Usage: use nu_modules/nix_config.nu

# Resolve the actual nix config directory (follows symlinks)
export def config-dir []: nothing -> string {
    let nix_config_link = $"($env.HOME)/.config/nix"
    $nix_config_link | path expand
}

# Path to machine.nix
export def machine-config-path []: nothing -> string {
    $"(config-dir)/machine.nix"
}

# Parse machine.nix and return {username, system, hostname} record
export def parse-machine-config [] {
    let path = (machine-config-path)
    if not ($path | path exists) {
        error make { msg: $"machine.nix not found at: ($path)" }
    }
    let content = (open $path --raw)
    let username = ($content | parse --regex 'username = "([^"]+)"' | get capture0.0)
    let system = ($content | parse --regex 'system = "([^"]+)"' | get capture0.0)
    let hostname = try {
        $content | parse --regex 'hostname = "([^"]+)"' | get capture0.0
    } catch {
        ""
    }
    { username: $username, system: $system, hostname: $hostname }
}
