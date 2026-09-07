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

Only run this **after a successful `dot rebuild`** — `chsh` to a path that does not exist yet leaves the machine unable to open terminals (Ghostty fails with "failed to launch the requested command: ... cannot execute: No such file or directory"). The guarded command below refuses to switch if nushell is not in the system profile yet.

```bash
NU=/run/current-system/sw/bin/nu
[ -x "$NU" ] && chsh -s "$NU" || echo "Run 'dot rebuild' first; $NU does not exist yet"
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
