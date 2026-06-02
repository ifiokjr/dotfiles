# Getting Started

This is the canonical onboarding guide for setting up these dotfiles on a new machine.

## Supported Platforms

- macOS
- Linux

Windows and BSD paths exist in some setup logic, but the main tested onboarding path is macOS and Linux.

## 1. Choose an Install Mode

### Safest default

Use the default `core` preset when you want a smaller blast radius on a new machine.

```bash
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash
```

This installs the foundational shell, editor, and CLI setup.

### Full workstation

Use the `workstation` preset for a personal machine where GUI-heavy tools are expected.

```bash
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --preset workstation
```

### Read-only preflight check

Run the doctor first if you want to validate the machine before making changes.

```bash
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --doctor
```

### Local clone workflow

Use a local clone if you want to inspect or modify the repo before running setup.

```bash
git clone https://github.com/ifiokjr/dotfiles.git ~/path/to/dotfiles
cd ~/path/to/dotfiles
./setup
```

## 2. What Setup Changes

The setup flow can:

- install Determinate Nix
- clone or reuse the dotfiles repository
- install temporary bootstrap tools such as `git`, `tuckr`, and `nushell`
- create the Tuckr symlink expected by the repo layout
- deploy selected config groups into your home directory via symlinks
- run post-hooks for groups such as `nix`, `nushell`, `pnpm`, and `agents`
- rebuild system or Home Manager configuration via `nh` when the `nix` group is deployed

The setup script is intentionally metadata-driven, but Tuckr remains the deployment engine.

## Starter Workflows

### I just want my shell and editor

```bash
./setup --preset core
```

Expected outcome:

- core shell tooling is deployed
- Nushell, Zsh compatibility, Helix, and shared scripts are configured
- GUI-heavy workstation additions stay out of the way

### I want a full macOS workstation

```bash
./setup --preset workstation
```

Expected outcome:

- developer tooling plus GUI-heavy workstation configuration is deployed
- Nix-managed and hook-driven machine setup runs
- this is the highest-blast-radius onboarding path

### I want a minimal CI or container install

```bash
./setup --preset ci --no-confirm
```

Expected outcome:

- a non-interactive, minimal setup path suitable for CI or containers
- no interactive prompts
- lighter bootstrap and deployment expectations than a workstation install

### I only want Nix and Nushell

```bash
./setup --groups scripts,nix,nushell
```

Expected outcome:

- shared scripts plus Nix and Nushell are deployed
- a narrower setup than the full presets
- useful when you want to adopt the stack incrementally

### I want to inspect the plan before changing anything

```bash
./setup --dry-run
./setup --doctor
```

Expected outcome:

- `--dry-run` shows the execution plan
- `--doctor` checks bootstrap readiness without changing the machine

## 3. Run Setup

### Common flags

- `--preset <name>`: choose `core`, `dev`, `workstation`, or `ci`
- `--groups <comma,list>`: deploy specific groups (comma-separated; overrides preset selection)
- `--cwd <path>`: clone to a custom location
- `--skip-nix`: skip Nix installation
- `--lite`: force CLI-focused mode
- `--no-confirm`: run without interactive confirmation
- `--dry-run`: show the execution plan without making changes
- `--list-groups`: list available configuration groups
- `--explain-group <name>`: show details for one configuration group
- `--resume`: resume from the last failed phase or group
- `--from <target>`: resume from a specific phase or deployment group
- `--only <groups>`: retry only the specified comma-separated groups
- `--validate-metadata`: validate `Configs/*.group.toml` and exit
- `--help`: print setup help

### Expected prompts and duration

Typical expectations:

- `core` on an already-prepared machine: several minutes
- `workstation` on macOS: potentially much longer because Nix, Home Manager, and GUI-heavy packages may be involved
- `nix` deployment may trigger a full rebuild or `nh home switch`
- macOS runs may request `sudo`

If you are unsure, start with `--doctor` and the default `core` preset.

## 4. Verify Success

Good first checks after setup:

```bash
command -v nix
command -v tuckr
command -v nu
tuckr status
```

Useful spot checks:

```bash
test -L ~/.config/nushell/config.nu
test -L ~/.config/helix/config.toml
test -L ~/.zshrc
```

Also:

- open a new terminal window
- confirm your expected shell/editor configuration is active
- run `dot rebuild` later if you want to re-apply Nix-managed changes after editing config

## 5. Common Failure Cases And Recovery

### Command Line Tools / macOS bootstrap issues

Symptoms:

- `git` exists but cannot run
- setup cannot complete the bootstrap phase cleanly

Try:

- run `./setup --doctor`
- install or repair Xcode Command Line Tools
- rerun setup

### GitHub rate limiting or network issues

Symptoms:

- slow or failed GitHub-backed fetches
- flaky installs in CI or on fresh machines

Try:

- set `GITHUB_TOKEN`
- rerun setup once connectivity is stable

### Nix rebuild or hook failures

Symptoms:

- `nix` deploy completes partially
- a post-hook fails during `tuckr set`

Try:

- inspect the failing group hook in `Hooks/<group>/post.sh`
- rerun `tuckr set <group>` or `dot rebuild` after correcting the underlying issue
- use `./setup --validate-metadata` if you suspect metadata drift

### Existing files conflict with Tuckr symlinks

Symptoms:

- setup retries with `--force`
- files already exist in home-directory destinations

Try:

- review the conflicting file
- back it up if needed
- rerun setup or use the relevant `tuckr` command directly

## 6. Undo / Roll Back

To remove a specific deployed group:

```bash
tuckr rm <group>
```

To inspect what is currently deployed:

```bash
tuckr status
```

If you want to stop using this repo on a machine entirely, remove deployed groups first, then remove the repo clone and any remaining symlinks deliberately rather than deleting files blindly.

## Related Docs

- [README](../readme.md)
- [Setup and deployment reference](agents/setup-and-deployment.md)
- [Repository architecture](agents/repository-architecture.md)
