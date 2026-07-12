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
    let user = $env | get -o USER | default (whoami)
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
# File descriptor limits
# ---------------------------------------------------------------------------
# macOS defaults to a 256-file-descriptor soft limit, which is too low for
# Nix evaluation, devenv, and other heavy workloads. Raise it for this
# Nushell process (and any child processes it spawns) as early as possible.
# Fall back to 65536 if the higher value is rejected by the kernel.
try { ulimit -n 524288 } catch {
    try { ulimit -n 65536 } catch { }
}

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
$env.EDITOR = "hx"
$env.SUDO_EDITOR = "hx"
# ---------------------------------------------------------------------------
# macOS
# ---------------------------------------------------------------------------
$env.MACOSX_DEPLOYMENT_TARGET = "12.0"
$env.ARCHFLAGS = "-arch arm64"
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
    let ndks = ls $ndk_base | where type == dir | sort-by name
    if ($ndks | is-not-empty) {
        $ndks | last | get name
    } else { $"($ndk_base)/29.0.13599879" }
} else { $"($ndk_base)/29.0.13599879" }
# ---------------------------------------------------------------------------
# pnpm
# ---------------------------------------------------------------------------
$env.PNPM_HOME = $"($env.HOME)/Library/pnpm"
# ---------------------------------------------------------------------------
# Docker compatibility via podman (macOS)
# ---------------------------------------------------------------------------
# Dynamically set DOCKER_HOST from the podman machine socket path.
# This enables Docker SDK clients (docker-py, Testcontainers, IronClaw) to
# connect to the podman VM. The `docker` CLI alias (podman) works without this.
# Falls back to the standard macOS Podman socket if dynamic detection fails.
if ($nu.os-info.name == "macos") and (which podman | is-not-empty) {
    let _docker_sock = (
        do -i { podman machine inspect podman-machine-default --format '{{.ConnectionInfo.PodmanSocket.Path}}' }
        | str trim
    )
    if ($_docker_sock | path exists) {
        $env.DOCKER_HOST = "unix://" + $_docker_sock
    } else if ("/tmp/podman/podman-machine-default-api.sock" | path exists) {
        $env.DOCKER_HOST = "unix:///tmp/podman/podman-machine-default-api.sock"
    }
}
# Always set a fallback for Linux hosts that may run this same env.nu.
if ($env | get -o DOCKER_HOST | is-empty) {
    if ("/run/podman/podman.sock" | path exists) {
        $env.DOCKER_HOST = "unix:///run/podman/podman.sock"
    } else if ("/var/run/docker.sock" | path exists) {
        $env.DOCKER_HOST = "unix:///var/run/docker.sock"
    }
}
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
# Suppress boehm-gc "Exclusion ranges overlap" warnings on macOS.
# The boehm-gc library (linked into nix) prints these harmless warnings
# to stderr during memory region setup, polluting devenv/direnv output.
$env.GC_LOG_FILE = "/dev/null"
# ---------------------------------------------------------------------------
# PATH (single consolidation point)
# ---------------------------------------------------------------------------
let path_prepend = [
    $"($env.HOME)/.local/bin"
    $"($env.HOME)/.cargo/bin"
    $"($env.HOME)/.shorebird/bin"
    $"($env.XDG_DATA_HOME? | default ($env.HOME | path join '.local/share'))/pnpm-global/node_modules/.bin"
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
# OpenCode
# ---------------------------------------------------------------------------
$env.OPENCODE_DANGEROUSLY_SKIP_PERMISSIONS = true
$env.OPENCODE_ALLOW_ALL_BASH = true
$env.OPENCODE_TRUSTED_DIRECTORIES = "/Users/ifiokjr/Developer,/tmp"
# ---------------------------------------------------------------------------
# Directory stack (like zsh auto_pushd)
# ---------------------------------------------------------------------------
$env.DIRSTACK = [$env.PWD]
# ---------------------------------------------------------------------------
# Devenv hook cache (runs in env.nu so the file exists before config.nu parses)
# ---------------------------------------------------------------------------
# Nushell's `source` is a parser keyword that resolves paths at parse time.
# Any runtime code in config.nu would execute too late. Since env.nu is
# fully parsed and executed before config.nu, we create/refresh the cache here.
mkdir ~/.cache/devenv
let devenv_bin = which devenv | get path.0 | default ''

let needs_regen = if ($devenv_bin | is-empty) { false } else {
    let cache_exists = $"($env.HOME)/.cache/devenv/hook.nu" | path exists
    if not $cache_exists { true } else {
        let cache_mtime = ls -l $"($env.HOME)/.cache/devenv/hook.nu" | get modified.0
        let bin_mtime = ls -l $devenv_bin | get modified.0
        ($cache_mtime < $bin_mtime)
    }
}
if $needs_regen {
    devenv hook nu | save --force ~/.cache/devenv/hook.nu
}
# Create empty placeholder if cache doesn't exist (e.g. devenv not installed)
if not ("~/.cache/devenv/hook.nu" | path expand | path exists) {
    "" | save --force ~/.cache/devenv/hook.nu
}
# pnpm
$env.PNPM_HOME = "/Users/ifiokjr/Library/pnpm"
$env.PATH = ($env.PATH | split row (char esep) | prepend ($env.PNPM_HOME | path join "bin"))
# pnpm end
# ---------------------------------------------------------------------------
# Codex API Keys
# ---------------------------------------------------------------------------
# Load API keys for custom Codex providers (Xiaomi MiMo, Ollama Cloud)
# Primary source: 1Password via Monosecret (use `msr codex ...`)
# Fallback: ~/.codex/secrets.env for offline use
if ("~/.codex/secrets.env" | path exists) {
    let secrets = (
        open ~/.codex/secrets.env --raw
        | lines
        | where {|l| not ($l | str starts-with '#') and ($l | str contains '=')}
        | parse '{key}={value}'
        | transpose -r
    )
    if ($secrets | get -o XIAOMI_MIMO_API_KEY | is-not-empty) {
        $env.XIAOMI_MIMO_API_KEY = ($secrets | get XIAOMI_MIMO_API_KEY)
    }
    if ($secrets | get -o OLLAMA_CLOUD_API_KEY | is-not-empty) {
        $env.OLLAMA_CLOUD_API_KEY = ($secrets | get OLLAMA_CLOUD_API_KEY)
    }
    if ($secrets | get -o OLLAMA_API_KEY | is-not-empty) {
        $env.OLLAMA_API_KEY = ($secrets | get OLLAMA_API_KEY)
    }
}
