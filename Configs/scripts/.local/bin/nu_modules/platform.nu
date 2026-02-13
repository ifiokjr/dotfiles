# platform.nu - Platform detection utilities for dotfiles scripts
#
# Provides OS, architecture, and hostname detection.
# Usage: use nu_modules/platform.nu

# Detect OS name
export def os []: nothing -> string {
    (sys host).name | if $in == "Darwin" { "darwin" } else { "linux" }
}

# Detect architecture in nix format
export def arch []: nothing -> string {
    let machine = (uname).machine
    match $machine {
        "arm64" | "aarch64" => "aarch64"
        "x86_64" => "x86_64"
        _ => { error make { msg: $"Unsupported architecture: ($machine)" } }
    }
}

# Get nix system triple (e.g., "aarch64-darwin")
export def nix-system []: nothing -> string {
    $"(arch)-(os)"
}

# Detect hostname (macOS uses scutil, Linux uses sys host)
export def detect-hostname []: nothing -> string {
    if (os) == "darwin" {
        try {
            ^scutil --get ComputerName | str trim
        } catch {
            (sys host).hostname
        }
    } else {
        (sys host).hostname
    }
}
