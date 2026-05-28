# platform.nu - Platform detection utilities for dotfiles scripts
#
# Provides OS, architecture, and hostname detection.
# Usage: use nu_modules/platform.nu
# Detect OS name
export def os [] {
    (sys host).name | if $in == "Darwin" { "darwin" } else { "linux" }
}
# Detect architecture in nix format.
# macOS reports "arm64" while Linux reports "aarch64" — normalize to nix convention.
export def arch [] {
    let machine = (uname).machine
    match $machine {
        "arm64" | "aarch64" => "aarch64"
        x86_64 => "x86_64"
        _ => { error make {
            msg: $"Unsupported architecture: ($machine)"
        } }
    }
}
# Get nix system triple (e.g., "aarch64-darwin")
export def nix-system [] { $"(arch)-(os)" }
# Detect hostname.
# macOS: prefer `scutil --get ComputerName` (user-friendly name like "John's MacBook")
# Linux: fall back to `sys host` which reads /etc/hostname
export def detect-hostname [] {
    if (os) == "darwin" {
        try {
            ^scutil --get ComputerName | str trim
        } catch { (sys host).hostname }
    } else { (sys host).hostname }
}
