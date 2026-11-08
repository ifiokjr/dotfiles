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
