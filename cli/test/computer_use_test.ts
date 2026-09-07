import { assert, assertEquals } from "@std/assert";
import { dirname, fromFileUrl, join } from "@std/path";

const cliDir = dirname(dirname(fromFileUrl(import.meta.url)));
const repoDir = dirname(cliDir);
const skillDir = join(
	repoDir,
	"Configs",
	"agents",
	".agents",
	"skills",
	"computer-use",
);

Deno.test("computer-use MCP config launches the Codex-managed client", async () => {
	const text = await Deno.readTextFile(join(skillDir, "mcp.json"));
	const config: unknown = JSON.parse(text);

	assert(isObject(config));
	assert(isObject(config.mcpServers));
	assert(isObject(config.mcpServers["computer-use"]));
	assertEquals(config.mcpServers["computer-use"].command, "/bin/sh");
	assertEquals(config.mcpServers["computer-use"].args, [
		"-c",
		'exec "${CODEX_HOME:-$HOME/.codex}/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient" mcp',
	]);
});

Deno.test("agents pre-hook preserves a legacy Codex export before deployment", async () => {
	const homeDir = await Deno.makeTempDir({ prefix: "computer-use-hook-" });
	const deployedDir = join(homeDir, ".agents", "skills", "computer-use");
	const backupDir = join(
		homeDir,
		".agents",
		"computer-use-codex-export",
	);

	try {
		await Deno.mkdir(join(deployedDir, "Codex Computer Use.app"), {
			recursive: true,
		});
		await Deno.writeTextFile(join(deployedDir, "SKILL.md"), "legacy");
		await Deno.writeTextFile(join(deployedDir, "mcp.json"), "{}");

		const command = new Deno.Command("bash", {
			args: ["pre.sh"],
			cwd: join(repoDir, "Hooks", "agents"),
			env: { HOME: homeDir },
			stderr: "piped",
			stdout: "piped",
		});
		const first = await command.output();

		assert(first.success);
		assertEquals(await pathExists(deployedDir), false);
		assertEquals(await pathExists(join(backupDir, "SKILL.md")), true);

		const second = await command.output();

		assert(second.success);
		assertEquals(await pathExists(join(backupDir, "mcp.json")), true);
	} finally {
		await Deno.remove(homeDir, { recursive: true });
	}
});

/** Check whether a path exists without coupling tests to its file type. */
async function pathExists(path: string): Promise<boolean> {
	try {
		await Deno.lstat(path);

		return true;
	} catch (error) {
		if (error instanceof Deno.errors.NotFound) {
			return false;
		}

		throw error;
	}
}

/** Narrow parsed JSON before reading the MCP server fields. */
function isObject(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null;
}
