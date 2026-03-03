# env.nu - Environment configuration for Nushell
# Runs before config.nu. Sets up PATH, Nix, and all environment variables.
$env._SHELL_START = (date now)
# ---------------------------------------------------------------------------
# Nix bootstrap
# ---------------------------------------------------------------------------
# When Nix env vars are missing (e.g. nushell is the login shell and
# nix-darwin's set-environment has not run), detect and set them manually.
if not ($env | get -o NIX_PROFILES | is-not-empty) {
    # Replicate nix-darwin's set-environment script
    let user = ($env | get -o USER | default "ifiokjr")
    # Nix profiles (matches nix-darwin set-environment)
    $env.NIX_PROFILES = $"/nix/var/nix/profiles/default /run/current-system/sw /etc/profiles/per-user/($user) ($env.HOME)/.nix-profile"
    $env.NIX_USER_PROFILE_DIR = $"/nix/var/nix/profiles/per-user/($user)"
    $env.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
    $env.__NIX_DARWIN_SET_ENVIRONMENT_DONE = "1"
    # TERMINFO
    $env.TERMINFO_DIRS = $"($env.HOME)/.nix-profile/share/terminfo:/etc/profiles/per-user/($user)/share/terminfo:/run/current-system/sw/share/terminfo:/nix/var/nix/profiles/default/share/terminfo:/usr/share/terminfo"
    # XDG directories
    $env.XDG_CONFIG_HOME = $"($env.HOME)/.config"
    $env.XDG_CONFIG_DIRS = $"($env.HOME)/.nix-profile/etc/xdg:/etc/profiles/per-user/($user)/etc/xdg:/run/current-system/sw/etc/xdg:/nix/var/nix/profiles/default/etc/xdg"
    $env.XDG_DATA_DIRS = $"($env.HOME)/.nix-profile/share:/etc/profiles/per-user/($user)/share:/run/current-system/sw/share:/nix/var/nix/profiles/default/share"
    # PATH (matches nix-darwin set-environment order)
    let nix_paths = [
        $"($env.HOME)/.nix-profile/bin"
        $"/etc/profiles/per-user/($user)/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
    ]
    let current_path = if ($env | get -o PATH | is-not-empty) {
        if ($env.PATH | describe) == "string" {
            $env.PATH | split row (char esep)
        } else { $env.PATH }
    } else { ["/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"] }
    $env.PATH = ($nix_paths | append $current_path)
}
# ---------------------------------------------------------------------------
# PATH coercion
# ---------------------------------------------------------------------------
# Ensure PATH is a list (may be inherited as a colon-separated string)
if ($env.PATH | describe) == "string" { $env.PATH = ($env.PATH | split row (char esep)) }
# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
$env.EDITOR = "hx"
$env.SUDO_EDITOR = "hx"
# ---------------------------------------------------------------------------
# macOS
# ---------------------------------------------------------------------------
$env.MACOSX_DEPLOYMENT_TARGET = "12.0"
$env.ARCHFLAGS = $"-arch (^uname -m | str trim)"
# ---------------------------------------------------------------------------
# Deno
# ---------------------------------------------------------------------------
$env.DENO_INSTALL = $"($env.HOME)/.deno"
# ---------------------------------------------------------------------------
# Android
# ---------------------------------------------------------------------------
$env.ANDROID_HOME = $"($env.HOME)/Library/Android/sdk"
let ndk_base = $"($env.ANDROID_HOME)/ndk"
$env.NDK_HOME = if ($ndk_base | path exists) {
    let ndks = (ls $ndk_base | where type == dir | sort-by name)
    if ($ndks | is-not-empty) {
        $ndks | last | get name
    } else { $"($ndk_base)/29.0.13599879" }
} else { $"($ndk_base)/29.0.13599879" }
# ---------------------------------------------------------------------------
# pnpm
# ---------------------------------------------------------------------------
let os_name = (^uname -s | str trim)
$env.PNPM_HOME = if $os_name == "Darwin" { $"($env.HOME)/Library/pnpm" } else { $"($env.HOME)/.local/share/pnpm" }
# ---------------------------------------------------------------------------
# GPG
# ---------------------------------------------------------------------------
$env.GPG_TTY = (try { tty } catch { "" })
# ---------------------------------------------------------------------------
# Carapace
# ---------------------------------------------------------------------------
# Bridge completions from other shells for broader coverage
$env.CARAPACE_BRIDGES = "zsh,fish,bash,inshellisense"
# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------
# Force epoch 0 for deterministic/reproducible Nix builds
$env.SOURCE_DATE_EPOCH = "0"
$env.DIRENV_LOG_FORMAT = ""
# ---------------------------------------------------------------------------
# PATH (single consolidation point)
# ---------------------------------------------------------------------------
let path_prepend = [
    $"($env.HOME)/.local/bin"
    $"($env.HOME)/.cargo/bin"
    $"($env.HOME)/.shorebird/bin"
    $env.PNPM_HOME
    $"($env.HOME)/.local/share/solana/install/active_release/bin"
    $"($env.HOME)/fvm/default/bin"
    $"($env.DENO_INSTALL)/bin"
]
let path_append = [
    $"($env.ANDROID_HOME)/cmdline-tools/latest/bin"
    $"($env.ANDROID_HOME)/platform-tools"
    "/Applications/Android Studio.app/Contents/MacOS"
    $"($env.HOME)/.pub-cache/bin"
    "/usr/local/bin"
]
$env.PATH = (
    $path_prepend | append $env.PATH | append $path_append | uniq
)
# ---------------------------------------------------------------------------
# Directory stack (like zsh auto_pushd)
# ---------------------------------------------------------------------------
$env.DIRSTACK = [
    $env.PWD
]
