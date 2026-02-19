---
name: tart-vm
description: >
  Spin up, control, and test inside macOS and Linux virtual machines using Tart
  (https://tart.run) on Apple Silicon Macs. Use this skill when the user wants
  to launch a VM, run commands inside it, take screenshots of the GUI, click or
  type in the desktop, run automated tests in a real desktop environment, or
  manage VM lifecycle (create, clone, snapshot, stop, delete). Requires an Apple
  Silicon Mac with macOS 13+ and Tart installed via Homebrew.
---

# Tart VM Skill

Launch, control, and test inside macOS/Linux virtual machines on Apple Silicon using [Tart](https://tart.run) by [Cirrus Labs](https://github.com/cirruslabs/tart).

---

## Quick Start

### Add to Claude

The post-deployment hook registers this MCP server automatically when you run:

```bash
tuckr set claude
```

Or register manually:

```bash
claude mcp add tart-vm -- deno run -A ~/.claude/skills/tart_vm_control/mcp-server-tart.ts
```

---

## Prerequisites

All dependencies are managed via nix (`home.nix`). No manual installation needed.

| Requirement  | Details                                        |
| ------------ | ---------------------------------------------- |
| **Hardware** | Apple Silicon Mac (M1/M2/M3/M4)                |
| **Host OS**  | macOS 13.0 (Ventura) or later                  |
| **Tart**     | Installed via Homebrew (`cirruslabs/cli/tart`) |
| **Deno**     | Provided by nix                                |
| **vncdo**    | Provided by nix (VNC-based GUI control)        |
| **sshpass**  | Provided by nix                                |

---

## Key Constraints

- **macOS VM limit:** Apple enforces a maximum of **2 concurrent macOS VMs** per host at the kernel level. Linux VMs have no such limit.
- **Disk space:** Each macOS image is ~25-50 GB. Use `tart prune` to reclaim.
- **Nested virtualization:** Only on M3/M4 chips with macOS 15+.
- **Boot time:** ~20-40s for macOS. Use the **warm VM pattern** to avoid this.

## VNC Modes

Tart supports two VNC modes. The MCP server defaults to **native VNC** for automation.

| Feature | `--vnc-experimental` (default) | `--vnc` (legacy) |
| --- | --- | --- |
| **Backend** | Apple's `_VZVNCServer` (host-side) | macOS Screen Sharing (guest) |
| **Works during install/recovery** | Yes | No |
| **Guest config needed** | None | Remote Login must be enabled |
| **Password** | Auto-generated 4-word passphrase | Guest credentials (admin/admin) |
| **Port** | Random ephemeral (OS-assigned) | 5900 (guest VNC) |
| **VNC binds to** | `127.0.0.1` (localhost only) | VM IP address |
| **Clipboard** | No (known regression) | Yes |

**Native VNC is preferred for automation** because it requires no guest setup and works even before the OS boots. The password and port are parsed from Tart's stdout output (`vnc://:<password>@127.0.0.1:<port>`).

---

## Recommended Approaches

### Approach 1: SSH-Based Testing (No GUI) — Best for scripts/builds

```bash
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest test-vm
tart run test-vm --no-graphics &
sleep 30
sshpass -p admin ssh -o StrictHostKeyChecking=no admin@$(tart ip test-vm) "swift test"
tart stop test-vm && tart delete test-vm
```

### Approach 2: Native VNC GUI Testing — Best for GUI automation

Uses Tart's built-in VNC (`--vnc-experimental`) + [vncdo](https://github.com/sibson/vncdotool) from the host. No guest tools needed.

```bash
tart run test-vm --no-graphics --vnc-experimental &
sleep 5
# Parse VNC URL from stdout: vnc://:<password>@127.0.0.1:<port>
vncdo -s localhost::<port> --password '<password>' capture screenshot.png
vncdo -s localhost::<port> --password '<password>' move 500 400 click 1
vncdo -s localhost::<port> --password '<password>' type "hello world" key enter
```

### Approach 2b: Bridged Networking — VM on local network

Give the VM a real IP on your LAN for network-dependent testing:

```bash
tart run test-vm --no-graphics --vnc-experimental --net-bridged=en0 &
sleep 30
# VM gets a real IP on your local network
tart ip test-vm  # returns LAN IP, e.g. 192.168.1.x
```

### Approach 3: Warm VM Pattern — Best for repeated testing

Resume from suspension in ~2-5s instead of cold booting in 30+.

```bash
# Suspend after setup
tart suspend warm-vm

# Each iteration: resume -> test -> suspend
tart run warm-vm --no-graphics --vnc-experimental &
sleep 5
# ... test ...
tart suspend warm-vm
```

---

## Available VM Images

From [GitHub Container Registry](https://github.com/orgs/cirruslabs/packages?repo_name=macos-image-templates):

| Image                 | Tag                                             |
| --------------------- | ----------------------------------------------- |
| macOS Sequoia (base)  | `ghcr.io/cirruslabs/macos-sequoia-base:latest`  |
| macOS Sequoia + Xcode | `ghcr.io/cirruslabs/macos-sequoia-xcode:latest` |
| macOS Sonoma (base)   | `ghcr.io/cirruslabs/macos-sonoma-base:latest`   |
| Ubuntu 24.04          | `ghcr.io/cirruslabs/ubuntu:24.04`               |
| Ubuntu 22.04          | `ghcr.io/cirruslabs/ubuntu:22.04`               |

**Default credentials:** `admin` / `admin`

---

## Command Reference

### Lifecycle

```bash
tart clone <image> <name>       # Clone from registry
tart create --from-ipsw=latest <name>  # From IPSW
tart create --linux <name>      # Empty Linux VM
tart run <name>                 # Start with GUI
tart run <name> --no-graphics --vnc-experimental  # Headless + native VNC
tart run <name> --no-graphics --vnc-experimental --net-bridged=en0  # + bridged network
tart run <name> --no-graphics --vnc  # Headless + guest Screen Sharing VNC
tart run <name> --dir=label:~/path   # With shared dir
tart stop <name>                # Stop
tart suspend <name>             # Suspend (warm pattern)
tart delete <name>              # Delete
tart list                       # List VMs
tart ip <name>                  # Get IP
```

### Configuration

```bash
tart set <name> --cpu 4 --memory 8192 --display 1920x1080
tart get <name>
```

### Execution

```bash
ssh admin@$(tart ip <name>)
sshpass -p admin ssh -o StrictHostKeyChecking=no admin@$(tart ip <name>) "cmd"
tart exec <name> -- command     # Requires guest agent
```

### GUI via VNC (host-side, native)

With `--vnc-experimental`, VNC runs on localhost. Parse password and port from Tart's stdout.

```bash
# Native VNC (--vnc-experimental) — connects to localhost
vncdo -s localhost::<port> --password '<password>' capture screenshot.png
vncdo -s localhost::<port> --password '<password>' move 500 400 click 1
vncdo -s localhost::<port> --password '<password>' type "text" key enter

# Legacy VNC (--vnc) — connects to guest VM IP
vncdo -s $(tart ip <name>)::5900 --password admin capture screenshot.png
```

---

## Baking a Golden Image

Pre-install tools so every clone is test-ready.

```bash
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest golden
tart run golden
# Inside VM: install tools, enable Accessibility, shut down
tart clone golden my-test   # instant test-ready clones
```

---

## MCP Server Tools

| Tool            | Description                      |
| --------------- | -------------------------------- |
| `vm_list`       | List all Tart VMs                |
| `vm_create`     | Clone from registry image        |
| `vm_start`      | Start headless + VNC             |
| `vm_stop`       | Stop (optionally delete)         |
| `vm_suspend`    | Suspend for warm VM pattern      |
| `vm_exec`       | Run command via SSH              |
| `vm_screenshot` | Capture GUI via VNC (base64 PNG) |
| `vm_click`      | Click at (x, y) via VNC          |
| `vm_type`       | Type text via VNC                |
| `vm_key`        | Press key combo via VNC          |
| `vm_open_url`   | Open URL in guest browser        |
| `vm_configure`  | Set CPU/memory/display           |

---

## Troubleshooting

| Problem            | Solution                                                        |
| ------------------ | --------------------------------------------------------------- |
| `tart ip` empty    | VM still booting. Wait 20-30s.                                  |
| SSH refused        | Enable Remote Login in VM System Settings.                      |
| VNC refused        | Start with `--vnc` flag.                                        |
| Max 2 macOS VMs    | Apple kernel limit. Stop one or use Linux VMs.                  |
| Slow cold boot     | Use warm VM pattern (`tart suspend` / resume).                  |
| Shared dir missing | macOS: `/Volumes/My Shared Files/`. Linux: `mount -t virtiofs`. |

---

## References

- [Tart](https://tart.run) · [GitHub](https://github.com/cirruslabs/tart) · [FAQ](https://tart.run/faq/)
- [Tart Guest Agent](https://github.com/cirruslabs/tart-guest-agent)
- [Tart Packer Plugin](https://github.com/cirruslabs/packer-plugin-tart)
- [macOS Images](https://github.com/orgs/cirruslabs/packages?repo_name=macos-image-templates) · [Linux Images](https://github.com/orgs/cirruslabs/packages?repo_name=linux-image-templates)
- [vncdo](https://github.com/sibson/vncdotool) · [API Docs](https://vncdotool.readthedocs.io/en/latest/library.html)
- [Deno](https://deno.land)
- [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization)
- [MCP Protocol](https://modelcontextprotocol.io)
