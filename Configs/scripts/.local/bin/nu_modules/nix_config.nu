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
            if ($repo_flake | path exists) { ($repo_flake | path expand | path dirname) } else { $link_dir }
        } else { $link_dir }
    }
}
# Path to machine.nix
export def machine-config-path [] { $"(config-dir)/machine.nix" }
# Set the machine.nix desktop mode flag (inserts the field if missing).
# When isDesktop=true AND lite=true on macOS, enables Docker via podman.
export def set-desktop-mode [value: bool, --path(-p): string] {
    let target_path = ($path | default (machine-config-path))
    if not ($target_path | path exists) {
        error make {
            msg: $"machine.nix not found at: ($target_path)"
        }
    }
    let content = (open $target_path --raw)
    let desktop_value = (if $value { "true" } else { "false" })
    let desktop_line = $"  isDesktop = ($desktop_value);"
    let updated = if ($content | str contains "isDesktop =") {
        $content | str replace --regex '(?m)^\s*isDesktop\s*=\s*(true|false);\s*$' $desktop_line
    } else {
        let with_desktop = $"\n  # Desktop machine — enables Docker via podman on lite macOS\n($desktop_line)\n}"
        $content | str replace --regex '\n\}\s*$' $with_desktop
    }
    $updated | save -f $target_path
}
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
# Set the machine.nix always-on mode flag (inserts the field if missing).
# When alwaysOn=true on macOS, the machine never sleeps and the screensaver
# activates with password lock after display sleep. Intended for always-plugged-in
# desktops (e.g. Mac Mini) that must stay reachable at all times.
export def set-always-on-mode [value: bool, --path(-p): string] {
    let target_path = ($path | default (machine-config-path))
    if not ($target_path | path exists) {
        error make {
            msg: $"machine.nix not found at: ($target_path)"
        }
    }
    let content = (open $target_path --raw)
    let always_on_value = (if $value { "true" } else { "false" })
    let always_on_line = $"  alwaysOn = ($always_on_value);"
    let updated = if ($content | str contains "alwaysOn =") {
        $content | str replace --regex '(?m)^\s*alwaysOn\s*=\s*(true|false);\s*$' $always_on_line
    } else {
        let with_always_on = $"\n  # Always-on — prevents sleep, enables screensaver with lock\n($always_on_line)\n}"
        $content | str replace --regex '\n\}\s*$' $with_always_on
    }
    $updated | save -f $target_path
}
# Known presets and their descriptions.
# These map to machine.nix `presets` list entries and Nix conditional logic.
#
# Adding a new preset:
#   1. Add it here with a description
#   2. Wire it into home.nix/darwin.nix to conditionally enable features
#   3. Add tuckr config groups with matching preset membership
export def known-presets [] { {ironclaw: "Ironclaw agent runtime — enables libSQL database and ironclaw service"} }
# Add a preset to machine.nix (inserts the presets list if missing, appends if present).
export def add-preset [preset: string, --path(-p): string] {
    let preset = ($preset | str downcase)
    let known = (known-presets)
    let preset_names = ($known | columns)
    if $preset not-in $preset_names {
        error make {
            msg: $"Unknown preset '($preset)'. Available presets: ($preset_names | str join ', ')"
        }
    }
    let target_path = ($path | default (machine-config-path))
    if not ($target_path | path exists) {
        error make {
            msg: $"machine.nix not found at: ($target_path)"
        }
    }
    let content = (open $target_path --raw)
    # Parse current presets list (if any)
    let current_entries = try {
        let raw = ($content | parse --regex 'presets\s*=\s*\[([^\]]*)\]' | get capture0.0 | str trim)
        if ($raw | is-empty) { [] } else {
            $raw | split row ' ' | where {|x| $x | is-not-empty} | each {|x| $x | str replace --all '"' '' | str trim }
        }
    } catch { [] }
    # Already present — no-op
    if $preset in $current_entries {
        return
    }
    let new_entries = ($current_entries | append $preset | each {|x| $'"($x)"'})
    let preset_line = $"  presets = [($new_entries | str join ' ')];"
    let updated = if ($content | str contains 'presets =') {
        $content | str replace --regex '(?m)^\s*presets\s*=\s*\[[^\]]*\];\s*$' $preset_line
    } else {
        let with_presets = $"\n  # Machine presets — determines which feature sets to enable\n($preset_line)\n}"
        $content | str replace --regex '\n\}\s*$' $with_presets
    }
    $updated | save -f $target_path
}
# Remove a preset from machine.nix (removes from the list, cleans up empty list).
export def remove-preset [preset: string, --path(-p): string] {
    let preset = ($preset | str trim | str downcase)
    let target_path = ($path | default (machine-config-path))
    if not ($target_path | path exists) {
        error make {
            msg: $"machine.nix not found at: ($target_path)"
        }
    }
    let content = (open $target_path --raw)
    if not ($content | str contains 'presets =') {
        return
    }
    # Parse current entries and remove the target
    let current_entries = try {
        let raw = ($content | parse --regex 'presets\s*=\s*\[([^\]]*)\]' | get capture0.0 | str trim)
        if ($raw | is-empty) { [] } else {
            $raw | split row ' ' | where {|x| $x | is-not-empty} | each {|x| $x | str replace --all '"' '' | str trim }
        }
    } catch { [] }
    let new_entries = ($current_entries | where {|x| $x != $preset} | each {|x| $'"($x)"'})
    let updated = if ($new_entries | length) > 0 {
        let preset_line = $"  presets = [($new_entries | str join ' ')];"
        $content | str replace --regex '(?m)^\s*presets\s*=\s*\[[^\]]*\];\s*$' $preset_line
    } else {
        # Remove the presets line entirely (and its comment)
        $content | str replace --regex '(?m)^[ \t]*#\s*Machine presets.*\n?[ \t]*presets\s*=\s*\[\s*\];\s*\n?' ''
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
    # isDesktop is optional — older machine.nix files may not have it
    let isDesktop = try { (($content | parse --regex 'isDesktop\s*=\s*(true|false);' | get capture0.0) == "true") } catch { false }
    # alwaysOn is optional — older machine.nix files may not have it
    let alwaysOn = try { (($content | parse --regex 'alwaysOn\s*=\s*(true|false);' | get capture0.0) == "true") } catch { false }
    # presets is optional — a quoted list inside brackets
    let presets = try {
        let raw = ($content | parse --regex 'presets\s*=\s*\[([^\]]*)\]' | get capture0.0 | str trim)
        if ($raw | is-empty) { [] } else {
            $raw | split row ' ' | where {|x| $x | is-not-empty} | each {|x| $x | str replace --all '"' '' | str trim }
        }
    } catch { [] }
    {
        username: $username
        system: $system
        hostname: $hostname
        lite: $lite
        isDesktop: $isDesktop
        alwaysOn: $alwaysOn
        presets: $presets
    }
}
