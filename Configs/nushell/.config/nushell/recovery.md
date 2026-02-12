# nushell recovery

If nushell breaks or you need to revert:

## Quick escape

- Nushell is the login shell (via `chsh`). If it breaks, open a terminal and run `/bin/bash` or `/bin/zsh`.
- On macOS, you can also use Terminal.app which may bypass Ghostty.

## Temporarily revert login shell

```bash
chsh -s /bin/zsh
```

Then open a new terminal window.

## Restore nushell as login shell

```bash
chsh -s /run/current-system/sw/bin/nu
```

## Remove nushell config

```bash
tuckr rm nushell
```

## Re-deploy nushell config

```bash
tuckr set nushell
```

## Debug startup issues

```bash
nu --log-level debug
```

## Check nushell config for errors

```bash
nu -c "echo 'config ok'"
```
