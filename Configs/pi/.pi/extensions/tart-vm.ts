/**
 * Tart VM Extension for pi
 *
 * Registers Tart VM management tools directly into pi via registerTool().
 * Auto-discovered from .pi/extensions/ — no post-hook or manual registration needed.
 *
 * Prerequisites (nix-managed via home.nix):
 *   - Apple Silicon Mac, macOS 13+
 *   - tart (via Homebrew / nix-homebrew)
 *   - sshpass, vncdo (via nix)
 *
 * References:
 *   - Tart: https://tart.run
 *   - vncdo: https://github.com/sibson/vncdotool
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { execSync, spawn } from "node:child_process";
import { existsSync, mkdirSync, readFileSync } from "node:fs";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const SCREENSHOT_DIR = `${process.env["TMPDIR"] ?? "/tmp"}/tart-vm-screenshots`;
try {
	mkdirSync(SCREENSHOT_DIR, { recursive: true });
} catch { /* exists */ }

const SSH_OPTS =
	"-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10";
const DEFAULT_USER = "admin";
const DEFAULT_PASS = "admin";
const VNC_PORT = 5900;

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
): { success: boolean; output: string; error?: string } {
	try {
		const out = execSync(cmd, { encoding: "utf8", timeout: 120_000 }).trim();
		return { success: true, output: out };
	} catch (e: unknown) {
		const err = e as { stdout?: string; stderr?: string; message?: string };
		const output = (err.stdout ?? "").trim();
		const error = (err.stderr ?? err.message ?? "unknown error").trim();
		return { success: false, output, error };
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
	);
}

function vncdo(
	vmName: string,
	args: string,
): { success: boolean; output: string; error?: string } {
	const info = vmVncInfo.get(vmName);
	if (info) {
		return run(
			`vncdo -s localhost::${info.port} --password '${info.password}' ${args}`,
		);
	}
	const ip = getIp(vmName);
	if (!ip) {
		return {
			success: false,
			output: "",
			error: "Cannot resolve VM IP for VNC",
		};
	}
	return run(`vncdo -s ${ip}::${VNC_PORT} --password ${DEFAULT_PASS} ${args}`);
}

function waitForBoot(
	vm: string,
	maxSec = 90,
): { success: boolean; ip?: string; error?: string } {
	const deadline = Date.now() + maxSec * 1000;
	while (Date.now() < deadline) {
		const ip = getIp(vm);
		if (ip) {
			const test = run(
				`sshpass -p '${DEFAULT_PASS}' ssh ${SSH_OPTS} ${DEFAULT_USER}@${ip} "echo ready"`,
			);
			if (test.success && test.output.includes("ready")) {
				return { success: true, ip };
			}
		}
		execSync("sleep 3");
	}
	return { success: false, error: `VM not reachable within ${maxSec}s` };
}

const ok = (text: string) => ({
	content: [{ type: "text" as const, text }],
	details: {},
});
const img = (b64: string, msg: string) => ({
	content: [
		{ type: "image" as const, data: b64, mimeType: "image/png" },
		{ type: "text" as const, text: msg },
	],
	details: {},
});

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function tartVmExtension(pi: ExtensionAPI) {
	pi.registerTool({
		name: "vm_list",
		label: "VM List",
		description: "List all Tart VMs on this host.",
		parameters: Type.Object({}),
		async execute(_id, _params) {
			const r = run("tart list");
			return ok(r.output || r.error || "No VMs found.");
		},
	});

	pi.registerTool({
		name: "vm_create",
		label: "VM Create",
		description:
			"Clone a VM from a registry image (e.g. ghcr.io/cirruslabs/macos-sequoia-base:latest). Default credentials: admin/admin.",
		parameters: Type.Object({
			image: Type.String({ description: "OCI image to clone" }),
			name: Type.String({ description: "Local VM name" }),
		}),
		async execute(_id, { image, name }) {
			const r = run(`tart clone ${image} ${name}`);
			return r.success
				? ok(`VM "${name}" created from ${image}\nCredentials: admin / admin`)
				: ok(`Failed: ${r.error}`);
		},
	});

	pi.registerTool({
		name: "vm_start",
		label: "VM Start",
		description:
			"Start a VM headless with Tart's native VNC (--vnc-experimental). Also resumes suspended VMs (~2-5s).",
		parameters: Type.Object({
			name: Type.String(),
			shared_dir: Type.Optional(
				Type.String({ description: "Host dir to share: label:/path" }),
			),
			net_bridged: Type.Optional(
				Type.String({
					description: "Interface for bridged networking, e.g. en0",
				}),
			),
			vnc_legacy: Type.Optional(
				Type.Boolean({
					description:
						"Use --vnc (guest Screen Sharing) instead of --vnc-experimental",
				}),
			),
		}),
		async execute(_id, params) {
			const { name, shared_dir, net_bridged, vnc_legacy } = params;
			let cmd = `tart run ${name} --no-graphics`;
			cmd += vnc_legacy ? " --vnc" : " --vnc-experimental";
			if (net_bridged) cmd += ` --net-bridged=${net_bridged}`;
			if (shared_dir) cmd += ` --dir=${shared_dir}`;

			const stdoutFile = `${SCREENSHOT_DIR}/tart-${name}-stdout.log`;
			spawn("bash", ["-c", `${cmd} > ${stdoutFile} 2>&1`], {
				detached: true,
				stdio: "ignore",
			}).unref();

			if (!vnc_legacy) {
				execSync("sleep 5");
				try {
					const content = readFileSync(stdoutFile, "utf8");
					const match = content.match(/vnc:\/\/:([^@]+)@[^:]+:(\d+)/);
					if (match) {
						vmVncInfo.set(name, {
							port: parseInt(match[2] as string),
							password: match[1] as string,
						});
					}
				} catch { /* VNC info unavailable */ }
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
						`VNC: vnc://localhost:${vncInfo.port} (host-side)`,
						`VNC password: ${vncInfo.password}`,
					);
				} else {
					lines.push(`VNC: vnc://${boot.ip} (guest Screen Sharing)`);
				}
				if (net_bridged) lines.push(`Network: bridged via ${net_bridged}`);
				return ok(lines.join("\n"));
			}
			const msg = [`Started but may still be booting: ${boot.error}`];
			if (vncInfo) msg.push(`VNC: vnc://localhost:${vncInfo.port}`);
			return ok(msg.join("\n"));
		},
	});

	pi.registerTool({
		name: "vm_stop",
		label: "VM Stop",
		description: "Stop a running VM. Optionally delete it afterward.",
		parameters: Type.Object({
			name: Type.String(),
			delete_after: Type.Optional(Type.Boolean()),
		}),
		async execute(_id, { name, delete_after }) {
			vmVncInfo.delete(name);
			let msg = "";
			const stop = run(`tart stop ${name}`);
			msg += stop.success ? `Stopped "${name}".` : `Warning: ${stop.error}`;
			if (delete_after) {
				const del = run(`tart delete ${name}`);
				msg += del.success ? " Deleted." : ` Delete failed: ${del.error}`;
			}
			return ok(msg);
		},
	});

	pi.registerTool({
		name: "vm_suspend",
		label: "VM Suspend",
		description:
			"Suspend a VM. Resume with vm_start in ~2-5s (warm VM pattern).",
		parameters: Type.Object({ name: Type.String() }),
		async execute(_id, { name }) {
			const r = run(`tart suspend ${name}`);
			return r.success
				? ok(`Suspended "${name}". Resume with vm_start (~2-5s).`)
				: ok(`Failed: ${r.error}`);
		},
	});

	pi.registerTool({
		name: "vm_exec",
		label: "VM Exec",
		description: "Run a shell command inside the VM via SSH.",
		parameters: Type.Object({ name: Type.String(), command: Type.String() }),
		async execute(_id, { name, command }) {
			const r = sshExec(name, command);
			return ok(
				r.success
					? (r.output || "(no output)")
					: `Failed: ${r.error}\n${r.output}`,
			);
		},
	});

	pi.registerTool({
		name: "vm_screenshot",
		label: "VM Screenshot",
		description:
			"Capture the VM screen via VNC. Returns a PNG image. No guest tools needed.",
		parameters: Type.Object({ name: Type.String() }),
		async execute(_id, { name }) {
			const ts = Date.now();
			const localPath = `${SCREENSHOT_DIR}/screenshot-${ts}.png`;

			const vnc = vncdo(name, `capture ${localPath}`);
			if (vnc.success && existsSync(localPath)) {
				const b64 = readFileSync(localPath).toString("base64");
				return img(b64, `Screenshot via VNC. Saved: ${localPath}`);
			}

			// SSH fallback
			const ip = getIp(name);
			if (ip) {
				const remote = `/tmp/screenshot-${ts}.png`;
				sshExec(
					name,
					`PID=$(pgrep loginwindow 2>/dev/null || echo 1); ` +
						`sudo launchctl bsexec $PID screencapture -x ${remote} 2>/dev/null || ` +
						`screencapture -x ${remote} 2>/dev/null`,
				);
				const scp = run(
					`sshpass -p '${DEFAULT_PASS}' scp ${SSH_OPTS} ${DEFAULT_USER}@${ip}:${remote} ${localPath}`,
				);
				if (scp.success && existsSync(localPath)) {
					const b64 = readFileSync(localPath).toString("base64");
					return img(b64, `Screenshot via SSH fallback. Saved: ${localPath}`);
				}
			}

			return ok(
				`Screenshot failed (VNC + SSH).\nVNC: ${vnc.error ?? "unknown"}\n` +
					`Ensure VM is running with --vnc-experimental and vncdo is installed.`,
			);
		},
	});

	pi.registerTool({
		name: "vm_click",
		label: "VM Click",
		description: "Click at (x, y) in the VM via VNC. No guest tools needed.",
		parameters: Type.Object({
			name: Type.String(),
			x: Type.Number(),
			y: Type.Number(),
			double_click: Type.Optional(Type.Boolean()),
		}),
		async execute(_id, { name, x, y, double_click }) {
			const clicks = double_click
				? `move ${x} ${y} click 1 click 1`
				: `move ${x} ${y} click 1`;
			const r = vncdo(name, clicks);
			return r.success ? ok(`Clicked (${x}, ${y})`) : ok(`Failed: ${r.error}`);
		},
	});

	pi.registerTool({
		name: "vm_type",
		label: "VM Type",
		description: "Type text into the VM via VNC.",
		parameters: Type.Object({ name: Type.String(), text: Type.String() }),
		async execute(_id, { name, text }) {
			const escaped = text.replaceAll("'", "'\\''");
			const r = vncdo(name, `type '${escaped}'`);
			return r.success ? ok(`Typed: "${text}"`) : ok(`Failed: ${r.error}`);
		},
	});

	pi.registerTool({
		name: "vm_key",
		label: "VM Key",
		description:
			"Press a key/combo in the VM via VNC (e.g. enter, ctrl-c, cmd-space).",
		parameters: Type.Object({ name: Type.String(), key: Type.String() }),
		async execute(_id, { name, key }) {
			const r = vncdo(name, `key ${key}`);
			return r.success ? ok(`Pressed: ${key}`) : ok(`Failed: ${r.error}`);
		},
	});

	pi.registerTool({
		name: "vm_open_url",
		label: "VM Open URL",
		description: "Open a URL in the VM's default browser via SSH.",
		parameters: Type.Object({ name: Type.String(), url: Type.String() }),
		async execute(_id, { name, url }) {
			const r = sshExec(name, `open '${url}'`);
			return r.success ? ok(`Opened: ${url}`) : ok(`Failed: ${r.error}`);
		},
	});

	pi.registerTool({
		name: "vm_configure",
		label: "VM Configure",
		description:
			"Set CPU, memory, or display for a VM. VM must be stopped first.",
		parameters: Type.Object({
			name: Type.String(),
			cpu: Type.Optional(Type.Number()),
			memory: Type.Optional(Type.Number({ description: "MB" })),
			display: Type.Optional(Type.String({ description: "e.g. 1920x1080" })),
		}),
		async execute(_id, { name, cpu, memory, display }) {
			let cmd = `tart set ${name}`;
			if (cpu) cmd += ` --cpu ${cpu}`;
			if (memory) cmd += ` --memory ${memory}`;
			if (display) cmd += ` --display ${display}`;
			const r = run(cmd);
			return r.success ? ok(`Configured "${name}".`) : ok(`Failed: ${r.error}`);
		},
	});
}
