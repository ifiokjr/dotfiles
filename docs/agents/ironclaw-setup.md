# IronClaw Multi-Machine Setup Guide

This documents the setup of IronClaw across your Mac (primary) and three Mac Minis (mini01, mini02, mini03), connected via Tailscale.

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    Tailscale Mesh                         │
│                                                           │
│  ┌─────────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │ MacBook Pro │  │ Mini 01  │  │ Mini 02  │  │ Mini 03  │ │
│  │ ifiokjr     │  │ mini01   │  │ mini02   │  │ mini03   │ │
│  │ IronClaw    │  │ IronClaw │  │ IronClaw │  │ IronClaw │ │
│  │ PG :5432    │  │ PG :5432 │  │ PG :5432 │  │ PG :5432 │ │
│  │Gateway:43210│  │ :43210   │  │ :43210   │  │ :43210   │ │
│  │ Ollama      │  │ Ollama   │  │ Ollama   │  │ Ollama   │ │
│  └─────────────┘  └──────────┘  └──────────┘  └──────────┘ │
│         │              │             │             │        │
│  ┌──────────────┐                                      │
│  │ iPhone/iPad  │  ← Tailscale VPN → SSH + Web Gateway │
│  └──────────────┘                                      │
└──────────────────────────────────────────────────────────┘
```

### Machine Details

| Machine     | Username  | Tailscale IP     | Purpose              |
| ----------- | --------- | ---------------- | -------------------- |
| MacBook Pro | `ifiokjr` | `100.123.36.92`  | Primary, development |
| Mini 01     | `ifiokjr` | `100.94.21.127`  | IronClaw worker      |
| Mini 02     | `ifiokjr` | `100.97.208.114` | IronClaw worker      |
| Mini 03     | `ifiokjr` | `100.77.105.14`  | IronClaw worker      |

> **Key**: All machines use OS username `ifiokjr`. The `machine.nix` file (gitignored) should set `username = "ifiokjr"` on every Mac, with only `hostname` changing per host.

---

## Prerequisites (Provided by Dotfiles)

Your `nix-darwin` + `home-manager` dotfiles already provide:

- ✅ Tailscale (Nix package in `home.nix`, daemon via `services.tailscale.enable`)
- ✅ Docker/OrbStack (Homebrew cask in `darwin.nix`)
- ✅ PostgreSQL client (`psql` via Nix)
- ✅ SSH (`openssh` via Nix)
- ✅ Shell tooling (zsh, nushell, zellij, atuin, etc.)
- ✅ Ollama (Nix package in `home.nix`)

## What Needed Adding (Not in Dotfiles Yet)

| Dependency       | Install Method | Status on MacBook Pro                       |
| ---------------- | -------------- | ------------------------------------------- |
| PostgreSQL 17    | Homebrew       | ✅ `brew install postgresql@17`             |
| pgvector         | Homebrew       | ✅ `brew install pgvector`                  |
| IronClaw binary  | Homebrew       | ✅ Already in Nix profile                   |
| IronClaw DB      | `createdb`     | ✅ `ironclaw` database created              |
| IronClaw service | launchd        | ✅ Installed via `ironclaw service install` |

---

## What Was Done on the MacBook Pro (Primary Machine)

### 1. PostgreSQL Setup

```bash
# Install PostgreSQL 17 and pgvector via Homebrew
brew install postgresql@17
brew install pgvector

# Start PostgreSQL as a persistent service
brew services start postgresql@17

# Create the IronClaw database
/opt/homebrew/opt/postgresql@17/bin/psql -d postgres -c "CREATE DATABASE ironclaw;"
/opt/homebrew/opt/postgresql@17/bin/psql -d ironclaw -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

> **Note**: We use the Homebrew PostgreSQL (`/opt/homebrew/opt/postgresql@17/bin/psql`) instead of the Nix-provided one because the Nix version can't find its share directory for `initdb`. The Nix `psql` client works fine for connecting, but the server must run via Homebrew.

### 2. IronClaw Configuration

Created `~/.ironclaw/.env`:

```env
# ─── Database ───
DATABASE_URL=postgres://ifiokjr@localhost/ironclaw
DATABASE_BACKEND=postgres
DATABASE_POOL_SIZE=10

# ─── LLM Provider (Ollama - local, private) ───
LLM_BACKEND=ollama
OLLAMA_MODEL=gemma4:latest
OLLAMA_BASE_URL=http://localhost:11434

# ─── Agent ───
AGENT_NAME=ironclaw-main
AGENT_MAX_PARALLEL_JOBS=5
AGENT_JOB_TIMEOUT_SECS=3600
AGENT_USE_PLANNING=true

# ─── Safety ───
SAFETY_INJECTION_CHECK_ENABLED=true
SAFETY_MAX_OUTPUT_LENGTH=100000

# ─── Self-repair ───
SELF_REPAIR_CHECK_INTERVAL_SECS=60
SELF_REPAIR_MAX_ATTEMPTS=3

# ─── Sandbox ───
SANDBOX_ENABLED=true
SANDBOX_POLICY=readonly

# ─── Web Gateway (listen on all interfaces for Tailscale) ───
GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=43210
GATEWAY_ENABLED=true
CLI_ENABLED=true
HTTP_ENABLED=false

# ─── Logging ───
RUST_LOG=ironclaw=info

# ─── Embeddings (disabled - NEAR AI not configured) ───
EMBEDDING_ENABLED=false

# ─── Suppress NEAR AI bootstrap ───
NEARAI_SESSION_TOKEN=
NEARAI_API_KEY=
```

### 3. Database Settings (via SQL)

Some settings are stored in the PostgreSQL `settings` table and override `.env`:

```sql
-- Already applied:
UPDATE settings SET value = 'true' WHERE key = 'sandbox.enabled';
UPDATE settings SET value = '"0.0.0.0"' WHERE key = 'channels.gateway_host';
UPDATE settings SET value = '3000' WHERE key = 'channels.gateway_port';
UPDATE settings SET value = 'true' WHERE key = 'channels.gateway_enabled';
UPDATE settings SET value = '"ironclaw-main"' WHERE key = 'agent.name';
UPDATE settings SET value = '"disabled"' WHERE key = 'embeddings.provider';
UPDATE settings SET value = 'false' WHERE key = 'embeddings.enabled';
```

### 4. IronClaw Service (launchd)

```bash
# Install as a macOS service
ironclaw service install

# Start/restart/stop/status
ironclaw service start
ironclaw service stop
ironclaw service status

# Plist location
~/Library/LaunchAgents/com.ironclaw.daemon.plist

# Logs
~/.ironclaw/logs/daemon.stdout.log
~/.ironclaw/logs/daemon.stderr.log
```

The service auto-starts on login and restarts on crash (`KeepAlive = true`).

### 5. Health Check

```bash
ironclaw doctor
# Expected output:
#   ✓ LLM configuration   backend=ollama, model=gemma4:latest
#   ✓ Database backend    PostgreSQL connected
#   ✓ Gateway config      enabled at 0.0.0.0:43210
#   ✓ Docker daemon       running
#   ✓ tailscale            1.98.0
#   ✓ Service             launchd plist installed

curl http://localhost:43210/api/health
# Expected: {"status":"healthy","channel":"gateway"}
```

---

## Mac Mini Setup (Repeat for Each)

### Step 1: Bootstrap with Dotfiles

```bash
# On each Mini, run:
curl -fsSL https://raw.githubusercontent.com/ifiokjr/dotfiles/refs/heads/main/setup | bash -s -- --preset dev
```

### Step 2: Configure `machine.nix`

Each Mini has a different `machine.nix` (gitignored, local to that machine):

```nix
# Mini 01: ~/.config/nix/machine.nix
{
  username = "ifiokjr";
  system = "aarch64-darwin";
  hostname = "mini01";
  lite = true;      # CLI-focused, no GUI apps
  isDesktop = true;  # Has Docker/Podman support
}
```

```nix
# Mini 02: ~/.config/nix/machine.nix
{
  username = "ifiokjr";
  system = "aarch64-darwin";
  hostname = "mini02";
  lite = true;
  isDesktop = true;
}
```

```nix
# Mini 03: ~/.config/nix/machine.nix
{
  username = "ifiokjr";
  system = "aarch64-darwin";
  hostname = "mini03";
  lite = true;
  isDesktop = true;
}
```

### Step 3: Login to Tailscale

```bash
sudo tailscale up --ssh
# The --ssh flag enables Tailscale SSH for remote access
```

### Step 4: Install PostgreSQL + pgvector

```bash
brew install postgresql@17
brew install pgvector
brew services start postgresql@17

# Create the database (as the local user)
createdb ironclaw
psql ironclaw -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### Step 5: Install IronClaw

```bash
# Via Homebrew (if available) or shell installer
brew install ironclaw
# OR:
# curl --proto '=https' --tlsv1.2 -LsSf https://github.com/nearai/ironclaw/releases/latest/download/ironclaw-installer.sh | sh
```

### Step 6: Configure IronClaw

```bash
# Run onboarding wizard
ironclaw onboard
# Choose:
#   - Database: postgres://<username>@localhost/ironclaw
#   - LLM: Ollama with gemma4:latest
#   - Tunnel: Static URL (skip, we use Tailscale mesh)

# Or create .env manually:
mkdir -p ~/.ironclaw
cat > ~/.ironclaw/.env << 'ENVEOF'
DATABASE_URL=postgres://mini01@localhost/ironclaw
DATABASE_BACKEND=postgres
DATABASE_POOL_SIZE=10

LLM_BACKEND=ollama
OLLAMA_MODEL=gemma4:latest
OLLAMA_BASE_URL=http://localhost:11434

AGENT_NAME=ironclaw-mini01
AGENT_MAX_PARALLEL_JOBS=3
AGENT_JOB_TIMEOUT_SECS=3600
AGENT_USE_PLANNING=true

SAFETY_INJECTION_CHECK_ENABLED=true
SAFETY_MAX_OUTPUT_LENGTH=100000
SELF_REPAIR_CHECK_INTERVAL_SECS=60
SELF_REPAIR_MAX_ATTEMPTS=3

SANDBOX_ENABLED=true
SANDBOX_POLICY=readonly

GATEWAY_HOST=0.0.0.0
GATEWAY_PORT=43210
GATEWAY_ENABLED=true
CLI_ENABLED=true
HTTP_ENABLED=false

RUST_LOG=ironclaw=info
EMBEDDING_ENABLED=false
NEARAI_SESSION_TOKEN=
NEARAI_API_KEY=
ENVEOF
```

> **Important**: Change `mini01` to `mini02`/`mini03` and `ironclaw-mini01` to `ironclaw-mini02`/`ironclaw-mini03` on each respective machine.

### Step 7: Install Ollama Model

```bash
# Ensure Ollama is running (comes from dotfiles/nix)
ollama serve &  # if not already running
ollama pull gemma4:latest
```

### Step 8: Install and Start IronClaw Service

```bash
ironclaw service install
ironclaw service start

# Verify
ironclaw doctor
curl http://localhost:43210/api/health
```

---

## Tailscale Configuration

### SSH Access

Tailscale SSH provides passwordless, keyless access between all machines.

**Enable on each machine:**

```bash
sudo tailscale up --ssh
```

**Configure in Tailscale ACL** (https://login.tailscale.com/admin/acl/):

```json
{
	"ssh": [
		{
			"action": "accept",
			"src": ["autogroup:members"],
			"dst": ["autogroup:members"],
			"users": ["ifiokjr", "mini01", "mini02", "mini03"]
		}
	]
}
```

**SSH config on the MacBook Pro** (`~/.ssh/config`):

```ssh
# ─── IronClaw Mac Minis (via Tailscale) ───

Host mini01
	HostName 100.94.21.127
	HostKeyAlias mini01.tailbfc6bf.ts.net
	User ifiokjr
	ProxyCommand tailscale nc %h %p
	UserKnownHostsFile ~/.ssh/known_hosts.tailscale
	StrictHostKeyChecking accept-new
	IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

Host mini02
	HostName 100.97.208.114
	HostKeyAlias mini02.tailbfc6bf.ts.net
	User ifiokjr
	ProxyCommand tailscale nc %h %p
	UserKnownHostsFile ~/.ssh/known_hosts.tailscale
	StrictHostKeyChecking accept-new
	IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

Host mini03
	HostName 100.77.105.14
	HostKeyAlias mini03.tailbfc6bf.ts.net
	User ifiokjr
	ProxyCommand tailscale nc %h %p
	UserKnownHostsFile ~/.ssh/known_hosts.tailscale
	StrictHostKeyChecking accept-new
	IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
```

> This SSH config is managed by Home Manager during `rebuild`. It uses `tailscale nc` as a proxy so SSH works even when the local Tailscale TUN interface is unavailable, and it stores Tailscale SSH host keys separately in `~/.ssh/known_hosts.tailscale`.

**Before SSH works, each Mini needs Remote Login enabled:**

On each Mac Mini (physical access or Screen Sharing):

```bash
sudo systemsetup -setremotelogin on
```

Or: System Settings → General → Sharing → Remote Login → ON

### Mobile Access (iPhone/iPad)

1. Install Tailscale from the App Store
2. Log in with the same account
3. Connect to the tailnet VPN
4. Access IronClaw web gateways in Safari:
   - `http://macbookpro:43210` (primary)
   - `http://mini01:43210`
   - `http://mini02:43210`
   - `http://mini03:43210`

---

## Switching LLM Provider

The default is Ollama (local, private). To switch to a cloud provider, edit `~/.ironclaw/.env`:

### Anthropic Direct

```env
LLM_BACKEND=anthropic
ANTHROPIC_API_KEY=sk-ant-...
ANTHROPIC_MODEL=claude-sonnet-4-20250514
```

### OpenRouter (300+ models)

```env
LLM_BACKEND=openai_compatible
LLM_BASE_URL=https://openrouter.ai/api/v1
LLM_API_KEY=sk-or-...
LLM_MODEL=anthropic/claude-sonnet-4
```

Then restart: `ironclaw service stop && ironclaw service start`

---

## Common Operations

```bash
# Check IronClaw status
ironclaw doctor

# View logs
tail -50 ~/.ironclaw/logs/daemon.stderr.log

# Restart service
ironclaw service restart

# Access REPL
ironclaw

# Access Web Gateway
open http://localhost:43210

# Update IronClaw
brew upgrade ironclaw

# Update PostgreSQL
brew upgrade postgresql@17

# Remote management (from MacBook Pro)
ssh mini01 "ironclaw doctor"
ssh mini01 "ironclaw service status"
ssh mini01 "tail -20 ~/.ironclaw/logs/daemon.stderr.log"
```

---

## Adding PostgreSQL + pgvector + IronClaw to Dotfiles (Future)

To make this declarative across all machines, add to your `darwin.nix`:

```nix
# In home.nix packages list, add:
postgresql_17

# In darwin.nix homebrew.brews list, add:
homebrew.brews = [
  "postgresql@17"
];
```

And create a new dotfiles group for IronClaw configuration:

```toml
# Configs/ironclaw.group.toml
description = "IronClaw AI assistant configuration"

# This would deploy ~/.ironclaw/.env and the launchd plist
```

This is not yet implemented — the current setup is manual per-machine until the group is created.

---

## Files and Paths

| Path                                               | Purpose                                              |
| -------------------------------------------------- | ---------------------------------------------------- |
| `~/.ironclaw/.env`                                 | Environment variables (LLM config, DB URL, etc.)     |
| `~/.ironclaw/logs/daemon.stderr.log`               | Error logs                                           |
| `~/.ironclaw/logs/daemon.stdout.log`               | Output logs                                          |
| `~/Library/LaunchAgents/com.ironclaw.daemon.plist` | macOS service definition                             |
| `/opt/homebrew/var/postgresql@17/`                 | PostgreSQL data directory                            |
| PostgreSQL `ironclaw` database                     | All IronClaw state (conversations, memory, settings) |

---

## Troubleshooting

### "Authentication error: Session renewal failed for provider nearai"

This is a non-fatal warning from IronClaw's default NEAR AI MCP bootstrap. It doesn't affect Ollama usage. To suppress it, set empty values in `.env`:

```env
NEARAI_SESSION_TOKEN=
NEARAI_API_KEY=
```

### PostgreSQL connection issues

```bash
# Check PostgreSQL is running
brew services list | grep postgresql

# Restart if needed
brew services restart postgresql@17

# Verify the database exists
/opt/homebrew/opt/postgresql@17/bin/psql -l | grep ironclaw
```

### IronClaw not starting

```bash
# Check logs
tail -50 ~/.ironclaw/logs/daemon.stderr.log

# Check service status
ironclaw service status

# Try running manually for detailed errors
ironclaw run
```

### Tailscale connectivity

```bash
# Check Tailscale status
tailscale status

# Ping a Mini
tailscale ping mini01

# Check SSH connectivity
ssh mini01 "echo connected"
```

If `tailscale ping` works but browser/curl access to tailnet IPs or MagicDNS names times out, check for another VPN intercepting the `100.64.0.0/10` Tailscale range. NordVPN can block Tailscale routes and MagicDNS; pause or disconnect NordVPN, then retry:

```bash
curl --max-time 8 http://mini02.tailbfc6bf.ts.net:43210/api/health
curl --max-time 8 http://100.97.208.114:43210/api/health
```
