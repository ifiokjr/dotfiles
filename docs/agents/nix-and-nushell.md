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
darwin-rebuild switch --flake ~/.config/nix#default --impure

# Linux/standalone Home Manager
home-manager switch --flake ~/.config/nix#username@system --impure
```

## Nix CLI Preference

Use `nix profile add`; avoid deprecated `nix profile install`.
