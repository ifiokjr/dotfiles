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

### Tools Available

The `tart-vm.ts` pi extension registers these tools automatically when pi starts — no manual registration or post-hook needed:

| Tool            | Description                      |
| --------------- | -------------------------------- |
| `vm_list`       | List all Tart VMs                |
| `vm_create`     | Clone from registry image        |
| `vm_start`      | Start headless + VNC             |
| `vm_stop`       | Stop (optionally delete)         |
| `vm_suspend`    | Suspend for warm VM pattern      |
| `vm_exec`       | Run command via SSH              |
| `vm_screenshot` | Capture GUI via VNC (PNG image)  |
| `vm_click`      | Click at (x, y) via VNC          |
| `vm_type`       | Type text via VNC                |
| `vm_key`        | Press key combo via VNC          |
| `vm_open_url`   | Open URL in guest browser        |
| `vm_configure`  | Set CPU/memory/display           |

### Setup

The extension is auto-discovered by pi from `.pi/extensions/tart-vm.ts` after deploying with tuckr:

```bash
tuckr add pi
```

---

## Prerequisites

All dependencies are managed via nix (`home.nix`). No manual installation needed.

| Requirement  | Details                                        |
| ------------ | ---------------------------------------------- |
| **Hardware** | Apple Silicon Mac (M1/M2/M3/M4)                |
| **Host OS**  | macOS 13.0 (Ventura) or later                  |
| **Tart**     | Installed via Homebrew (`cirruslabs/cli/tart`) |
| **vncdo**    | Provided by nix (VNC-based GUI control)        |
| **sshpass**  | Provided by nix                                |

---

## Key Constraints

- **macOS VM limit:** Apple enforces a maximum of **2 concurrent macOS VMs** per host at the kernel level. Linux VMs have no such limit.
- **Disk space:** Each macOS image is ~25-50 GB. Use `tart prune` to reclaim.
- **Nested virtualization:** Only on M3/M4 chips with macOS 15+.
- **Boot time:** ~20-40s for macOS. Use the **warm VM pattern** to avoid this.

## VNC Modes

Tart supports two VNC modes. The extension defaults to **native VNC** for automation.

| Feature                           | `--vnc-experimental` (default)     | `--vnc` (legacy)                |
| --------------------------------- | ---------------------------------- | ------------------------------- |
| **Backend**                       | Apple's `_VZVNCServer` (host-side) | macOS Screen Sharing (guest)    |
| **Works during install/recovery** | Yes                                | No                              |
| **Guest config needed**           | None                               | Remote Login must be enabled    |
| **Password**                      | Auto-generated 4-word passphrase   | Guest credentials (admin/admin) |
| **Port**                          | Random ephemeral (OS-assigned)     | 5900 (guest VNC)                |
| **VNC binds to**                  | `127.0.0.1` (localhost only)       | VM IP address                   |

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

Use `vm_start` then `vm_screenshot`, `vm_click`, `vm_type` tools.

### Approach 3: Warm VM Pattern — Best for repeated testing

Resume from suspension in ~2-5s instead of cold booting in 30+.

Use `vm_suspend` after setup, then `vm_start` to resume for each test iteration.

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

```bash
tart clone <image> <name>       # Clone from registry
tart run <name> --no-graphics --vnc-experimental  # Headless + native VNC
tart run <name> --no-graphics --vnc  # Headless + guest Screen Sharing VNC
tart stop <name>                # Stop
tart suspend <name>             # Suspend (warm pattern)
tart delete <name>              # Delete
tart list                       # List VMs
tart ip <name>                  # Get IP
tart set <name> --cpu 4 --memory 8192 --display 1920x1080
```

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
- [vncdo](https://github.com/sibson/vncdotool)
- [macOS Images](https://github.com/orgs/cirruslabs/packages?repo_name=macos-image-templates) · [Linux Images](https://github.com/orgs/cirruslabs/packages?repo_name=linux-image-templates)
- [Apple Virtualization Framework](https://developer.apple.com/documentation/virtualization)
