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
