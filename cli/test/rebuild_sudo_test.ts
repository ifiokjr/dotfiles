import { assertEquals } from "@std/assert";
import { stopSudoKeepalive, sudoKeepaliveScript } from "../commands/rebuild.ts";

Deno.test("sudoKeepaliveScript refreshes sudo for the rebuild process", () => {
	const script = sudoKeepaliveScript(4242);

	// Keeps running while the rebuild process exists...
	assertEquals(script.startsWith("while kill -0 4242"), true);
	// ...refreshes non-interactively so it can never prompt in the background...
	assertEquals(script.includes("sudo -nv"), true);
	// ...and sleeps between refreshes.
	assertEquals(script.includes("sleep 5"), true);
});

Deno.test("sudoKeepaliveScript exits immediately for a dead pid", async () => {
	// A pid far beyond the macOS pid_max range is guaranteed not to exist, so
	// `kill -0` fails on the first iteration and the loop exits without ever
	// reaching sudo.
	const deadPid = 99999999;

	const start = performance.now();
	const command = new Deno.Command("bash", {
		args: ["-c", sudoKeepaliveScript(deadPid)],
		stdin: "null",
		stdout: "null",
		stderr: "null",
	});
	const output = await command.output();
	const elapsedMs = performance.now() - start;

	assertEquals(output.success, true);
	assertEquals(elapsedMs < 2000, true);
});

Deno.test("sudoKeepaliveScript exits without prompting when sudo fails", async () => {
	// A fake sudo that always fails emulates an invalidated timestamp (e.g.
	// brew's `sudo --reset-timestamp`): the loop must exit silently instead of
	// hanging in the background.
	const binDir = await Deno.makeTempDir({ prefix: "fake-sudo-" });
	const sudoPath = `${binDir}/sudo`;
	await Deno.writeTextFile(sudoPath, "#!/bin/sh\nexit 1\n");
	await Deno.chmod(sudoPath, 0o755);

	const command = new Deno.Command("/bin/bash", {
		args: ["-c", sudoKeepaliveScript(Deno.pid)],
		env: { PATH: binDir },
		clearEnv: true,
		stdin: "null",
		stdout: "null",
		stderr: "null",
	});
	const output = await command.output();

	assertEquals(output.success, true);
	await Deno.remove(binDir, { recursive: true });
});

Deno.test("stopSudoKeepalive tolerates an already-terminated keepalive", async () => {
	// The keepalive exits on its own once the sudo ticket is invalidated, and
	// Deno throws when killing a terminated process. Stopping such a keepalive
	// must be a no-op instead of crashing the rebuild in its finally block.
	const command = new Deno.Command("true");
	const keepalive = command.spawn();
	await keepalive.status;

	stopSudoKeepalive(keepalive);

	// Also safe when there is nothing to stop (non-macOS or failed auth).
	stopSudoKeepalive(null);
});
