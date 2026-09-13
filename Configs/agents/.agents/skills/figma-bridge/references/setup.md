# Figma bridge — setup reference

Full bootstrap for the ZCode ↔ Figma write bridge. All paths below are the ones
currently in use on this machine.

## 1. Relay + MCP server (one-time)

```bash
mkdir -p ~/Developer/tools && cd ~/Developer/tools
git clone --depth 1 https://github.com/sonnylazuardi/cursor-talk-to-figma-mcp.git
cd cursor-talk-to-figma-mcp
bun install                     # needs bun on PATH
```

Then strip the plugin's analytics domain. This repo keeps the patch at
`zcode-ga-strip.patch`; apply it with `git apply zcode-ga-strip.patch` on a fresh clone
(the only change: removing `https://www.google-analytics.com` from `allowedDomains` and
`devAllowedDomains` in `src/cursor_mcp_plugin/manifest.json`).

Verify the MCP server speaks protocol:

```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  | bun src/talk_to_figma_mcp/server.ts
```

It should print `TalkToFigmaMCP` and 44 tools including `set_text_content`.

Start / stop the relay with the bundled helper:

```bash
~/Developer/tools/cursor-talk-to-figma-mcp/zcode-bridge.sh start   # ws://localhost:3055
~/Developer/tools/cursor-talk-to-figma-mcp/zcode-bridge.sh status
~/Developer/tools/cursor-talk-to-figma-mcp/zcode-bridge.sh logs
~/Developer/tools/cursor-talk-to-figma-mcp/zcode-bridge.sh stop
```

## 2. ZCode registration

In `~/.zcode/cli/config.json` under `mcp.servers` (canonical fields only; the schema is
strict):

```json
"figma-bridge": {
  "type": "stdio",
  "command": "/etc/profiles/per-user/ifiokjr/bin/bun",
  "args": ["/Users/ifiokjr/Developer/tools/cursor-talk-to-figma-mcp/src/talk_to_figma_mcp/server.ts"],
  "timeoutMs": 30000
}
```

Restart the ZCode session after editing; tools appear as `mcp__figma-bridge__*`.

## 3. Figma plugin import

1. In the Figma desktop app, open any **Design** file and make sure the toolbelt is in
   Design mode (not Dev Mode — Figma rejects `editorType: ["figma"]` plugins in Dev Mode
   with "The manifest editorType does not include 'dev'").
2. Quick actions (`⌘/`) → `Import plugin from manifest…` (or Plugins ▸ Development).
3. Select `~/Developer/tools/cursor-talk-to-figma-mcp/src/cursor_mcp_plugin/manifest.json`.
4. Run it: quick actions → `Cursor MCP Plugin`, or Plugins ▸ Development ▸ Cursor MCP Plugin.
5. The plugin window shows `Connected to server in channel: <name>`. Keep the window open
   for the whole session — closing it stops the bridge.
6. In ZCode, call `join_channel` with that exact channel name.

To apply manifest changes (e.g. after reapplying `zcode-ga-strip.patch`): close the
plugin window, re-import from the same manifest, and run it again.

## 4. Optional: read-only companion

The official desktop server registered as `figma` (`http://127.0.0.1:3845/mcp`, enabled
in Figma via quick actions → *Enable desktop MCP server*) provides `get_design_context`,
`get_screenshot`, `get_variable_defs`, `get_metadata`, `get_motion_context`, and
`get_figjam`. Read-only; no channel or plugin needed, but Figma must be running.

## Security notes

- The plugin is third-party code with **write access** to any open Figma document.
  Review changes before running large bulk edits.
- The upstream manifest shipped `https://www.google-analytics.com` in `networkAccess`
  (anonymous usage events). This machine strips it via `zcode-ga-strip.patch`; re-apply
  after `git pull` and re-import the plugin.
- The relay and channel join are unauthenticated loopback IPC on port 3055: anything
  local that knows the channel name can drive the plugin.
