#!/usr/bin/env -S deno run -A

/**
 * Tart VM MCP Server (Deno)
 *
 * Exposes Tart VM operations as MCP tools. Uses vncdo (VNC) for GUI
 * screenshots and interaction from the host. SSH fallback for commands.
 *
 * Add to Claude:
 *   claude mcp add tart-vm -- deno run -A /path/to/mcp-server-tart.ts
 *
 * Prerequisites (nix-managed):
 *   - Apple Silicon Mac, macOS 13+
 *   - tart, sshpass, deno, vncdo (all via nix)
 *
 * References:
 *   - Tart: https://tart.run
 *   - vncdo: https://github.com/sibson/vncdotool
 *   - MCP SDK: https://github.com/modelcontextprotocol/sdk
 *   - Deno: https://deno.land
 */

import { Server } from "npm:@modelcontextprotocol/sdk@latest/server/index.js";
import { StdioServerTransport } from "npm:@modelcontextprotocol/sdk@latest/server/stdio.js";
import {
	CallToolRequestSchema,
	ListToolsRequestSchema,
} from "npm:@modelcontextprotocol/sdk@latest/types.js";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const SCREENSHOT_DIR = `${
	Deno.env.get("TMPDIR") || "/tmp"
}/tart-vm-screenshots`;
try {
	Deno.mkdirSync(SCREENSHOT_DIR, { recursive: true });
} catch { /* exists */ }

const SSH_OPTS =
	`-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10`;
const DEFAULT_USER = "admin";
const DEFAULT_PASS = "admin";
const VNC_PORT = 5900;

// Track Tart's native VNC info per VM (--vnc-experimental)
interface VncInfo {
	port: number;
	password: string;
}
const vmVncInfo: Map<string, VncInfo> = new Map();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function run(
	cmd: string,
	_timeoutMs = 60_000,
): { success: boolean; output: string; error?: string } {
	try {
		const proc = new Deno.Command("bash", {
			args: ["-c", cmd],
			stdout: "piped",
			stderr: "piped",
		});
		const { code, stdout, stderr } = proc.outputSync();
		const out = new TextDecoder().decode(stdout).trim();
		const err = new TextDecoder().decode(stderr).trim();
		if (code === 0) return { success: true, output: out };
		return { success: false, output: out, error: err || `exit code ${code}` };
	} catch (e) {
		return { success: false, output: "", error: (e as Error).message };
	}
}

function getIp(vm: string): string | null {
	const r = run(`tart ip ${vm}`);
	return r.success && r.output ? r.output : null;
}

function sshExec(
	vm: string,
	command: string,
): { success: boolean; output: string; error?: string } {
	const ip = getIp(vm);
	if (!ip) {
		return {
			success: false,
			output: "",
			error: "Cannot resolve VM IP. Is it running?",
		};
	}
	const escaped = command.replaceAll('"', '\\"');
	return run(
		`sshpass -p '${DEFAULT_PASS}' ssh ${SSH_OPTS} ${DEFAULT_USER}@${ip} "${escaped}"`,
		120_000,
	);
}

function vncdo(vmName: string, args: string) {
	const info = vmVncInfo.get(vmName);
	if (info) {
		// Use Tart's native VNC on localhost (--vnc-experimental)
		return run(
			`vncdo -s localhost::${info.port} --password '${info.password}' ${args}`,
			30_000,
		);
	}
	// Fallback: connect to guest VNC via VM IP (--vnc mode)
	const ip = getIp(vmName);
	if (!ip) {
		return { success: false, output: "", error: "Cannot resolve VM IP for VNC" };
	}
	return run(
		`vncdo -s ${ip}::${VNC_PORT} --password ${DEFAULT_PASS} ${args}`,
		30_000,
	);
}

function sleep(sec: number) {
	run(`sleep ${sec}`);
}

function waitForBoot(
	vm: string,
	maxSec = 90,
): { success: boolean; ip?: string; error?: string } {
	const start = Date.now();
	while ((Date.now() - start) / 1000 < maxSec) {
		const ip = getIp(vm);
		if (ip) {
			const test = run(
				`sshpass -p '${DEFAULT_PASS}' ssh ${SSH_OPTS} ${DEFAULT_USER}@${ip} "echo ready"`,
				10_000,
			);
			if (test.success && test.output.includes("ready")) {
				return { success: true, ip };
			}
		}
		sleep(3);
	}
	return { success: false, error: `VM not reachable within ${maxSec}s` };
}

// ---------------------------------------------------------------------------
// Tools
// ---------------------------------------------------------------------------

const TOOLS = [
	{
		name: "vm_list",
		description: "List all Tart VMs on this host.",
		inputSchema: { type: "object" as const, properties: {} },
	},
	{
		name: "vm_create",
		description:
			"Clone a VM from a registry image (e.g. ghcr.io/cirruslabs/macos-sequoia-base:latest). Credentials: admin/admin.",
		inputSchema: {
			type: "object" as const,
			properties: {
				image: { type: "string", description: "OCI image to clone" },
				name: { type: "string", description: "Local VM name" },
			},
			required: ["image", "name"],
		},
	},
	{
		name: "vm_start",
		description:
			"Start a VM headless with Tart's native VNC (--vnc-experimental). Also resumes suspended VMs (~2-5s). VNC runs on localhost with auto-generated password and random port.",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				shared_dir: {
					type: "string",
					description: "Host dir to share (label:/path)",
				},
				net_bridged: {
					type: "string",
					description:
						"Network interface for bridged networking (e.g. en0, Wi-Fi). VM gets a real IP on the local network.",
				},
				vnc_legacy: {
					type: "boolean",
					description:
						"Use --vnc (guest Screen Sharing) instead of --vnc-experimental (host-side VNC). Requires Remote Login enabled in guest.",
				},
			},
			required: ["name"],
		},
	},
	{
		name: "vm_stop",
		description: "Stop a running VM. Optionally delete it.",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				delete_after: { type: "boolean" },
			},
			required: ["name"],
		},
	},
	{
		name: "vm_suspend",
		description:
			"Suspend a VM. Resume with vm_start in ~2-5s (warm VM pattern).",
		inputSchema: {
			type: "object" as const,
			properties: { name: { type: "string" } },
			required: ["name"],
		},
	},
	{
		name: "vm_exec",
		description: "Run a shell command inside the VM via SSH.",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				command: { type: "string" },
			},
			required: ["name", "command"],
		},
	},
	{
		name: "vm_screenshot",
		description:
			"Capture the VM screen via VNC. Returns base64 PNG. No guest tools needed.",
		inputSchema: {
			type: "object" as const,
			properties: { name: { type: "string" } },
			required: ["name"],
		},
	},
	{
		name: "vm_click",
		description: "Click at (x, y) via VNC. Host-side, no guest tools needed.",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				x: { type: "number" },
				y: { type: "number" },
				double_click: { type: "boolean" },
			},
			required: ["name", "x", "y"],
		},
	},
	{
		name: "vm_type",
		description: "Type text into the VM via VNC.",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				text: { type: "string" },
			},
			required: ["name", "text"],
		},
	},
	{
		name: "vm_key",
		description: "Press a key/combo via VNC (e.g. enter, ctrl-c, cmd-space).",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				key: { type: "string" },
			},
			required: ["name", "key"],
		},
	},
	{
		name: "vm_open_url",
		description: "Open a URL in the VM's default browser via SSH.",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				url: { type: "string" },
			},
			required: ["name", "url"],
		},
	},
	{
		name: "vm_configure",
		description: "Set CPU, memory, or display. VM must be stopped.",
		inputSchema: {
			type: "object" as const,
			properties: {
				name: { type: "string" },
				cpu: { type: "number" },
				memory: { type: "number", description: "MB" },
				display: { type: "string", description: "e.g. 1920x1080" },
			},
			required: ["name"],
		},
	},
];

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

type Args = Record<string, unknown>;

const text = (msg: string) => ({
	content: [{ type: "text" as const, text: msg }],
});
const image = (b64: string, msg: string) => ({
	content: [
		{ type: "image" as const, data: b64, mimeType: "image/png" },
		{ type: "text" as const, text: msg },
	],
});

async function handle(tool: string, args: Args) {
	switch (tool) {
		case "vm_list": {
			const r = run("tart list");
			return text(r.output || r.error || "No VMs found.");
		}

		case "vm_create": {
			const r = run(`tart clone ${args.image} ${args.name}`, 600_000);
			return r.success
				? text(
					`VM "${args.name}" created from ${args.image}\nCredentials: admin / admin`,
				)
				: text(`Failed: ${r.error}`);
		}

		case "vm_start": {
			const name = args.name as string;
			const useLegacyVnc = args.vnc_legacy === true;

			let cmd = `tart run ${name} --no-graphics`;
			cmd += useLegacyVnc ? ` --vnc` : ` --vnc-experimental`;
			if (args.net_bridged) cmd += ` --net-bridged=${args.net_bridged}`;
			if (args.shared_dir) cmd += ` --dir=${args.shared_dir}`;

			const stdoutFile = `${SCREENSHOT_DIR}/tart-${name}-stdout.log`;

			const proc = new Deno.Command("bash", {
				args: ["-c", `${cmd} > ${stdoutFile} 2>&1`],
				stdin: "null",
				stdout: "null",
				stderr: "null",
			});
			proc.spawn();

			// Parse VNC URL from Tart's stdout (--vnc-experimental)
			// Format: vnc://:<password>@127.0.0.1:<port>
			if (!useLegacyVnc) {
				sleep(5);
				try {
					const content = Deno.readTextFileSync(stdoutFile);
					const match = content.match(
						/vnc:\/\/:([^@]+)@[^:]+:(\d+)/,
					);
					if (match) {
						vmVncInfo.set(name, {
							port: parseInt(match[2]),
							password: match[1],
						});
					}
				} catch { /* VNC info will be unavailable */ }
			}

			const boot = waitForBoot(name, 90);
			const vncInfo = vmVncInfo.get(name);
			if (boot.success) {
				const lines = [
					`VM "${name}" running`,
					`IP: ${boot.ip}`,
					`SSH: ssh admin@${boot.ip}`,
				];
				if (vncInfo) {
					lines.push(
						`VNC: vnc://localhost:${vncInfo.port} (Tart native, host-side)`,
						`VNC password: ${vncInfo.password}`,
					);
				} else {
					lines.push(`VNC: vnc://${boot.ip} (guest Screen Sharing)`);
				}
				if (args.net_bridged) {
					lines.push(`Network: bridged via ${args.net_bridged}`);
				}
				return text(lines.join("\n"));
			}
			const msg = [`Started but may still be booting: ${boot.error}`];
			if (vncInfo) {
				msg.push(`VNC: vnc://localhost:${vncInfo.port}`);
			}
			return text(msg.join("\n"));
		}

		case "vm_stop": {
			const name = args.name as string;
			vmVncInfo.delete(name);
			let msg = "";
			const stop = run(`tart stop ${name}`);
			msg += stop.success
				? `Stopped "${name}".`
				: `Warning: ${stop.error}`;
			if (args.delete_after) {
				const del = run(`tart delete ${name}`);
				msg += del.success ? " Deleted." : ` Delete failed: ${del.error}`;
			}
			return text(msg);
		}

		case "vm_suspend": {
			const r = run(`tart suspend ${args.name}`);
			return r.success
				? text(
					`Suspended "${args.name}". Resume with vm_start (~2-5s).`,
				)
				: text(`Failed: ${r.error}`);
		}

		case "vm_exec": {
			const r = sshExec(args.name as string, args.command as string);
			return text(
				r.success
					? (r.output || "(no output)")
					: `Failed: ${r.error}\n${r.output}`,
			);
		}

		case "vm_screenshot": {
			const name = args.name as string;
			const ts = Date.now();
			const localPath = `${SCREENSHOT_DIR}/screenshot-${ts}.png`;

			const vnc = vncdo(name, `capture ${localPath}`);
			if (vnc.success) {
				try {
					const data = Deno.readFileSync(localPath);
					const b64 = btoa(String.fromCharCode(...data));
					return image(
						b64,
						`Screenshot via VNC. Saved: ${localPath}`,
					);
				} catch { /* fall through */ }
			}

			// SSH fallback (requires VM IP)
			const ip = getIp(name);
			if (ip) {
				const remote = `/tmp/screenshot-${ts}.png`;
				sshExec(
					name,
					`PID=$(pgrep loginwindow 2>/dev/null || echo 1); ` +
						`sudo launchctl bsexec $PID screencapture -x ${remote} 2>/dev/null || ` +
						`screencapture -x ${remote} 2>/dev/null || ` +
						`DISPLAY=:0 scrot ${remote} 2>/dev/null`,
				);
				const scp = run(
					`sshpass -p '${DEFAULT_PASS}' scp ${SSH_OPTS} ${DEFAULT_USER}@${ip}:${remote} ${localPath}`,
				);
				if (scp.success) {
					try {
						const data = Deno.readFileSync(localPath);
						const b64 = btoa(String.fromCharCode(...data));
						return image(
							b64,
							`Screenshot via SSH fallback. Saved: ${localPath}`,
						);
					} catch { /* fall through */ }
				}
			}

			return text(
				`Screenshot failed (VNC + SSH).\n` +
					`VNC: ${vnc.error || "unknown"}\n` +
					`Ensure VM is running with --vnc-experimental and vncdo installed.`,
			);
		}

		case "vm_click": {
			const name = args.name as string;
			const clicks = args.double_click
				? `move ${args.x} ${args.y} click 1 click 1`
				: `move ${args.x} ${args.y} click 1`;
			const r = vncdo(name, clicks);
			return r.success
				? text(`Clicked (${args.x}, ${args.y})`)
				: text(`Failed: ${r.error}`);
		}

		case "vm_type": {
			const name = args.name as string;
			const escaped = (args.text as string).replaceAll("'", "'\\''");
			const r = vncdo(name, `type '${escaped}'`);
			return r.success
				? text(`Typed: "${args.text}"`)
				: text(`Failed: ${r.error}`);
		}

		case "vm_key": {
			const name = args.name as string;
			const r = vncdo(name, `key ${args.key}`);
			return r.success
				? text(`Pressed: ${args.key}`)
				: text(`Failed: ${r.error}`);
		}

		case "vm_open_url": {
			const r = sshExec(args.name as string, `open '${args.url}'`);
			return r.success
				? text(`Opened: ${args.url}`)
				: text(`Failed: ${r.error}`);
		}

		case "vm_configure": {
			let cmd = `tart set ${args.name}`;
			if (args.cpu) cmd += ` --cpu ${args.cpu}`;
			if (args.memory) cmd += ` --memory ${args.memory}`;
			if (args.display) cmd += ` --display ${args.display}`;
			const r = run(cmd);
			return r.success
				? text(`Configured "${args.name}".`)
				: text(`Failed: ${r.error}`);
		}

		default:
			return text(`Unknown tool: ${tool}`);
	}
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

const server = new Server(
	{ name: "tart-vm", version: "2.0.0" },
	{ capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
	tools: TOOLS,
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
	try {
		return await handle(
			request.params.name,
			(request.params.arguments ?? {}) as Args,
		);
	} catch (e) {
		return text(`Error: ${(e as Error).message}`);
	}
});

const transport = new StdioServerTransport();
await server.connect(transport);
console.error("Tart VM MCP Server (Deno) running on stdio");
