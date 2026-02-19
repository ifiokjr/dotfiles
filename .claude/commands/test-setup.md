---
disable-model-invocation: true
---

# Test Setup Script in a Fresh macOS VM

You are testing the dotfiles `setup` script end-to-end in a fresh macOS virtual machine using Tart. Follow these phases exactly. **Always clean up the VM, even on failure.**

## Variables

- **VM name:** `test-setup-{{timestamp}}` (use current epoch seconds for `{{timestamp}}`)
- **VM image:** `ghcr.io/cirruslabs/macos-sequoia-base:latest`
- **VM credentials:** `admin` / `admin`
- **MCP server:** `tart-vm` (tools: `mcp__tart-vm__vm_*`)
- **Success marker:** The string `Setup Complete!` in `/tmp/setup.log`
- **Max retries:** 3
- **Disk size:** The base image is 50GB; the full nix config uses ~30GB. Disk pressure is expected.

---

## Phase 1: Pre-flight checks

1. Run `git branch --show-current` to get the current branch name. **Abort if on `main`** — you must be on a feature branch.
2. Run `git status` to check for uncommitted changes. If there are any, commit them with an appropriate conventional commit message and push.
3. Run `git push -u origin <branch>` to ensure the branch is pushed to the remote. Record the branch name for later.

## Phase 2: Create the VM

1. Use `mcp__tart-vm__vm_list` to check for existing VMs. If there are already 2 macOS VMs running, **abort** with a message explaining the Apple 2-VM kernel limit and asking the user to stop one.
2. If there is an existing VM whose name starts with `test-setup-`, ask the user if they want to delete it first (to reclaim disk space).
3. Use `mcp__tart-vm__vm_create` to clone the VM:
   - `name`: the VM name from Variables
   - `image`: `ghcr.io/cirruslabs/macos-sequoia-base:latest`
4. Use `mcp__tart-vm__vm_start` to start the VM headless:
   - `name`: the VM name
5. Wait 40 seconds for the VM to boot, then verify connectivity by running a simple command via `mcp__tart-vm__vm_exec`:
   - `command`: `echo "VM is ready"`
   - If this fails, wait another 20 seconds and retry (up to 3 times).

## Phase 2.5: Verify and fix VM networking

Tart's default NAT networking can break when VPN/tunnel interfaces (utun*) are active on the host.

1. Test internet connectivity inside the VM:
   ```
   curl -s --max-time 15 https://api.github.com/zen
   ```
2. If this **succeeds**, skip to Phase 3.
3. If this **fails** (timeout or empty response), set up an SSH reverse SOCKS proxy as a workaround: a. From the host, run:
   ```
   sshpass -p admin ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -R 1080 -N -f admin@192.168.65.2
   ```
   b. Verify the proxy works inside the VM:
   ```
   curl -s --max-time 10 --socks5 localhost:1080 https://api.github.com/zen
   ```
   c. Configure the VM environment so all tools use the proxy:
   ```
   echo 'export ALL_PROXY=socks5://localhost:1080' >> ~/.zprofile
   echo 'export ALL_PROXY=socks5://localhost:1080' >> ~/.zshrc
   echo 'export ALL_PROXY=socks5://localhost:1080' >> ~/.bash_profile
   echo 'export ALL_PROXY=socks5://localhost:1080' >> ~/.bashrc
   ```
   d. Configure sudo to preserve the proxy env var (needed for `darwin-rebuild`):
   ```
   echo 'Defaults env_keep += "ALL_PROXY http_proxy https_proxy HTTPS_PROXY HTTP_PROXY"' | sudo tee /etc/sudoers.d/proxy
   sudo chmod 440 /etc/sudoers.d/proxy
   ```
   e. Set proxy in root's environment:
   ```
   echo 'export ALL_PROXY=socks5://localhost:1080' | sudo tee -a /var/root/.zshrc
   echo 'export ALL_PROXY=socks5://localhost:1080' | sudo tee -a /var/root/.zprofile
   ```
   f. Add proxy environment to the Nix daemon's launchd plist (needed for nix downloads):
   ```
   sudo /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables dict" /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
   sudo /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:ALL_PROXY string socks5://localhost:1080" /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
   sudo /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:http_proxy string socks5://localhost:1080" /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
   sudo /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:https_proxy string socks5://localhost:1080" /Library/LaunchDaemons/systems.determinate.nix-daemon.plist
   ```
   Note: The Nix daemon plist modifications will only take effect after Nix is installed. Run these commands **after** Nix installation if the setup script installs Nix, or skip if Nix is not yet installed.
4. When starting setup with the proxy, always prefix:
   ```
   ALL_PROXY=socks5://localhost:1080 nohup ./setup --no-confirm > /tmp/setup.log 2>&1 &
   ```

## Phase 3: Run the setup script

1. Clone the dotfiles repo into the VM. If the SOCKS proxy was configured in Phase 2.5, prefix with `ALL_PROXY=socks5://localhost:1080`. Use `mcp__tart-vm__vm_exec` with:
   ```
   ALL_PROXY=socks5://localhost:1080 git clone -b <branch> https://github.com/ifiokjr/dotfiles.git ~/Developer/.dotfiles
   ```
2. Start the setup script in the background so the SSH session does not timeout. If the SOCKS proxy was configured, include `ALL_PROXY`:
   ```
   cd ~/Developer/.dotfiles && ALL_PROXY=socks5://localhost:1080 nohup ./setup --no-confirm > /tmp/setup.log 2>&1 &
   ```
3. Immediately verify the process started:
   ```
   sleep 2 && pgrep -f './setup' > /dev/null && echo "setup running" || echo "setup NOT running"
   ```

## Phase 4: Monitor progress

Poll the setup log every **60 seconds** until completion or failure. On each poll:

1. Use `mcp__tart-vm__vm_exec` to run:
   ```
   tail -80 /tmp/setup.log 2>/dev/null || echo "LOG NOT FOUND"
   ```
2. Also check if the process is still alive:
   ```
   pgrep -f './setup' > /dev/null && echo "PROCESS: running" || echo "PROCESS: exited"
   ```
3. **Success condition:** The log contains `Setup Complete!` — proceed to Phase 6.
4. **Failure condition:** The process has exited AND the log does NOT contain `Setup Complete!` — proceed to Phase 5.
5. **Timeout:** If 45 minutes have elapsed since Phase 3 started, treat it as a failure and proceed to Phase 5.
6. While waiting, summarize the last few meaningful log lines to the user so they can follow progress.
7. **SSH auth note:** If `mcp__tart-vm__vm_exec` fails with "Too many authentication failures", retry with a shorter command (e.g., `echo ok`) first to re-establish the connection, then retry the original command. This happens when the host SSH agent has many keys.

## Phase 5: Fix and retry (max 3 attempts)

If the setup failed:

1. Fetch the full error context from the VM:
   ```
   tail -200 /tmp/setup.log
   ```
2. Analyze the error. Common failures include:
   - **Nix build errors** — broken packages, hash mismatches, platform issues
   - **Tuckr hook failures** — missing commands, permission errors
   - **Network errors** — transient download failures (retry without code changes)
   - **Disk space errors** — "No space left on device" means the 50GB VM disk is full. Run `nix-collect-garbage -d` inside the VM to free Nix store space, then retry. If still insufficient, this is a known limitation of the base image size.
3. Fix the issue in the **local** dotfiles repo (not in the VM). Edit the source files as needed.
4. Commit the fix with a conventional commit message and push to the branch.
5. Pull the fix into the VM:
   ```
   cd ~/Developer/.dotfiles && git pull origin <branch>
   ```
6. Clear the old log and re-run setup:
   ```
   rm -f /tmp/setup.log && cd ~/Developer/.dotfiles && nohup ./setup --no-confirm > /tmp/setup.log 2>&1 &
   ```
7. Return to Phase 4 to monitor again.
8. After 3 failed retry attempts, proceed to Phase 7 (cleanup) and report the unresolved error to the user.

## Phase 6: Verify the setup

After `Setup Complete!` is found in the log:

1. Verify key tools are available in the VM:
   ```
   which tuckr && tuckr status
   ```
   ```
   which nu && nu --version
   ```
   ```
   which darwin-rebuild && echo "darwin-rebuild available"
   ```
2. Take a screenshot of the VM desktop using `mcp__tart-vm__vm_screenshot` and show it to the user.
3. Report success with a summary of:
   - Total time elapsed
   - Number of retries needed (if any)
   - Key tools verified

## Phase 7: Cleanup (ALWAYS runs)

**This phase must execute regardless of success or failure.** Even if earlier phases abort or error out, clean up the VM.

1. Use `mcp__tart-vm__vm_stop` with:
   - `name`: the VM name
   - `delete`: `true`
2. Confirm the VM is gone by running `mcp__tart-vm__vm_list`.
3. If `vm_stop` fails, try once more. If it still fails, tell the user to manually run: `tart stop <vm-name> && tart delete <vm-name>`

## Phase 8: Final report

1. Summarize what happened:
   - Whether setup succeeded or failed
   - What fixes were made (list commits)
   - Any remaining issues
2. Confirm all fix commits have been pushed to the remote branch.
3. If fixes were made and all checks pass, suggest opening a pull request against `main`.
