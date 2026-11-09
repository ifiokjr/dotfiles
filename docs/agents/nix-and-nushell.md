# Nix And Nushell

## Nushell String Interpolation Rule

In Nushell interpolated strings, escape parentheses with a single backslash:

- Correct: `$"Checking pane \(editor\)"`
- Incorrect: `$"Checking pane \\(editor\\)"`
- Incorrect: `$"Checking pane (editor)"`

Unescaped parentheses can trigger command substitution.

## Nix Configuration Files

- `Configs/nix/.config/nix/flake.nix`
- `Configs/nix/.config/nix/darwin.nix`
- `Configs/nix/.config/nix/home.nix`

## Nix Build Commands

```bash
# macOS
nh darwin switch ~/.config/nix -H default --impure

# Linux/standalone Home Manager
nh home switch ~/.config/nix -c username@system --impure
```

## Nix CLI Preference

Use `nix profile add`; avoid deprecated `nix profile install`.

## Rust Builds Run Through mbx

`cargo` is globally wrapped by [mr boxington](https://github.com/jdx/mr-boxington) (`mbx`) so every Rust project shares one build cache without per-repo changes. Both managed shells put mbx's shim directory first on `PATH`: `~/.zshenv` (for non-interactive shells and agents) and `Configs/nushell/.config/nushell/env.nu` (Nushell does not read zsh files). The shim is a no-op where mbx is not installed, and it falls back to `mbx` on `PATH`. `MBX_DISABLE=1` opts a single command out, and `mbx gc` reclaims build output from the shared cache.

## Android SDK In Every Shell

`Configs/shell/.config/shell/android.sh` sets `ANDROID_HOME`, `NDK_HOME`, `ANDROID_USER_HOME`, and `ANDROID_AVD_HOME`, and appends the SDK's `cmdline-tools`, `platform-tools`, and `emulator` to `PATH`. `env.sh` sources it for interactive shells and `~/.zshenv` sources it for every zsh shell, so agents and scripts can build Android apps and boot emulators without an interactive shell. `ANDROID_USER_HOME` follows `XDG_CONFIG_HOME` because nix-darwin sets it: without it, `avdmanager` writes AVDs to `~/.config/.android` while the emulator looks in `~/.android`. The emulator ignores `ANDROID_USER_HOME` for AVDs, so `ANDROID_AVD_HOME` is set as well; it prefers the existing `~/.android/avd` directory so AVDs created before the XDG-aware setup stay visible, and only fresh machines use `$ANDROID_USER_HOME/avd`. `env.nu` mirrors the same variables for Nushell.

On desktop macOS machines, `./setup` provisions the SDK itself (pinned command-line tools, platform-tools, emulator, system image, and a first AVD). That keeps T3 Code's connected-device host working after a reinstall without requiring Android Studio, which is skipped in `--lite` mode. Use `--no-android-sdk` to opt out or `--android-sdk` to force it on a machine whose `machine.nix` does not mark it as a desktop.
