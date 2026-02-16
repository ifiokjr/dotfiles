# nix_config.nu - Nix configuration path resolution
#
# Shared utilities for resolving nix config paths and parsing machine.nix.
# Usage: use nu_modules/nix_config.nu
# Resolve the nix config link directory (~/.config/nix).
# This is where machine.nix and nix.conf live. May be a real directory
# containing tuckr file-level symlinks, or a directory symlink itself.
export def config-dir [] {
    let nix_config_link = $"($env.HOME)/.config/nix"
    $nix_config_link | path expand
}
# Resolve the actual flake directory (follows symlinks to the git repo).
#
# Nix flake evaluation needs the real git repo path for `--flake`. When
# ~/.config/nix/ is a real directory with tuckr file-level symlinks, nix
# mangles the path (concatenating the symlink target with the parent dir).
# This function follows the flake.nix symlink to find the real directory.
# Mirrors the resolve_flake_dir logic in Hooks/nix/post.sh.
export def flake-dir [] {
    let link_dir = (config-dir)
    let flake_path = $"($link_dir)/flake.nix"
    if not ($flake_path | path exists) { 
    # No flake.nix found — fall back to config-dir
    return $link_dir }
    # Use realpath to fully resolve all symlinks in the chain
    let real_flake = (^realpath $flake_path | str trim)
    $real_flake | path dirname
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
