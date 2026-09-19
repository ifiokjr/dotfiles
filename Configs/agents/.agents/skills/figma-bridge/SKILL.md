---
name: figma-bridge
description: Read and write Figma designs from ZCode through the local plugin bridge (mcp__figma-bridge__* tools). Use whenever a task involves changing anything in Figma, such as editing text or copy in a Figma page, creating/renaming/moving nodes, updating fills, frames or text styles, or when the user says "connect to Figma", "join the Figma channel", "update the Figma file", "sync the copy in Figma", or asks to make Figma changes from the editor. Also use it to bring the bridge up (relay, Figma app, Cursor MCP Plugin) before any Figma work, and to diagnose Figma tool timeouts.
---

# Figma bridge

The `mcp__figma-bridge__*` tools can read **and write** the Figma file that is open in
the Figma desktop app. They work through a three-part chain; if any link is down the
tools return errors like "Must join a channel" or "Request to Figma timed out".

```
ZCode session ─ MCP server "figma-bridge" (stdio, spawned per session)
                     └─ ws://localhost:3055  relay: zcode-bridge.sh
                          └─ Figma plugin "Cursor MCP Plugin" (runs in the desktop app)
                               └─ Figma Plugin API → the open document
```

Tooling paths (this machine):

- Repo: `~/Developer/tools/cursor-talk-to-figma-mcp` (pin noted in `ZCODE-SETUP.md`)
- Relay control: `~/Developer/tools/cursor-talk-to-figma-mcp/zcode-bridge.sh start|stop|status|logs`
- ZCode entry: `figma-bridge` in `~/.zcode/cli/config.json`

## Preflight

Bring the chain up before any Figma tool call.

1. Check the relay with `~/Developer/tools/cursor-talk-to-figma-mcp/zcode-bridge.sh status`.
   If it reports STOPPED, run `... start` (it prints the log path). Never start a second copy.
2. Check the Figma app. With computer-use, call `list_apps` and look for `com.figma.Desktop`.
   If it is not running, call `open_application` with `{"bundle_id": "com.figma.Desktop"}`.
   Figma must have a design file open.
3. Check the plugin. With computer-use, call `get_app_state` on the Figma window and look for a
   `Cursor MCP Plugin` element. Take a screenshot (`include_screenshot: true`) and read
   the status line in the plugin window:
   - `Connected to server in channel: <name>` (green) means connected; note the exact name.
   - Button says `Disconnect` means connected; button says `Connect` means click it and wait a
     few seconds, then re-read the channel (it changes on every connect).
   - Plugin window missing means run it: press `cmd+/` in Figma, type `Cursor MCP Plugin`,
     and press the result (or use Plugins ▸ Development ▸ Cursor MCP Plugin).
     The file must be in Design mode. Figma refuses `editorType: ["figma"]`
     plugins while Dev Mode is active, so switch the toolbelt to Design first
     (`shift+d` toggles Dev Mode).

Then call `join_channel` with the channel name exactly as shown, and confirm with
`get_document_info` before doing real work. A first call right after joining can time
out while the plugin warms up, so wait two seconds and retry once.

## Using the tools

- The tools act on the currently open Figma file; selection-based reads use the current
  selection, or pass an explicit `nodeId` (e.g. from a `figma.com/design/...?node-id=1-2`
  link, which becomes `1:2`).
- Text work: `scan_text_nodes` to inventory copy, `set_text_content` /
  `set_multiple_text_contents` to edit, `create_text` to add, `get_node_info` to verify.
- Structural work: `create_frame`, `move_node`, `rename_node`, `set_fill_color`,
  `set_layout_mode`, `set_padding`, `create_component_instance`, and more.
- Edits are real and immediate. Name anything you create for a test (e.g.
  `zcode-verify`) and delete it with `delete_node` when done. Prefer describing a
  planned bulk change before running it; Figma undo (⌘Z) is the safety net.
- The channel join is local-only IPC on loopback; nothing leaves the machine. Keep
  tree addresses, tokens, and file keys out of user-facing output.

## Troubleshooting

| Symptom | Cause / action |
|---|---|
| `Must join a channel before sending commands` | Call `join_channel` with the channel shown in the plugin window. |
| `Error joining channel: Not connected to Figma` | The MCP server's socket is still opening; retry the join after 2 to 3 seconds. |
| `Request to Figma timed out` | The plugin lost its relay connection, and its green status can be stale. Open the plugin window, click `Disconnect` then `Connect`, re-read the new channel, re-join. |
| Relay log says `No other clients in channel ...` | Same as above: the plugin is not connected. Check with `zcode-bridge.sh logs`. |
| Import fails: `manifest editorType does not include "dev"` | The file is in Dev Mode; switch to Design mode and import again. |
| No `mcp__figma-bridge__*` tools at all | The `figma-bridge` server is missing or disabled in `~/.zcode/cli/config.json`, or the session predates it. Restart the session; see `references/setup.md`. |
| Relay starts but tools still fail | Confirm port 3055 belongs to the relay: `lsof -nP -iTCP:3055 -sTCP:LISTEN`. |

## Reinstall and first-time setup

If the clone, plugin, or ZCode entry is missing, follow `references/setup.md`. Note the
local patch `zcode-ga-strip.patch` (Google Analytics domain removed from the plugin
manifest); re-apply it with `git apply zcode-ga-strip.patch` after any `git pull`, then
re-import the plugin so Figma picks up the clean manifest.
