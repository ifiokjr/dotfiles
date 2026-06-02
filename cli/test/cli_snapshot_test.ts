import { assertEquals } from "@std/assert";
import { dirname, fromFileUrl, join } from "@std/path";
import { assertSnapshot } from "@std/testing/snapshot";

const cliDir = dirname(dirname(fromFileUrl(import.meta.url)));
const repoDir = dirname(cliDir);
const mainPath = join(cliDir, "main.ts");

interface CliResult {
	code: number;
	stderr: string;
	stdout: string;
}

function stripAnsi(value: string): string {
	let result = "";
	let index = 0;

	while (index < value.length) {
		if (value.charCodeAt(index) === 27 && value[index + 1] === "[") {
			index += 2;

			while (index < value.length && value[index] !== "m") {
				index++;
			}

			index++;
			continue;
		}

		result += value[index];
		index++;
	}

	return result;
}

function scrubOutput(value: string): string {
	return stripAnsi(value)
		.split("\n")
		.map((line) => {
			if (line.startsWith("Platform: ")) return "Platform: <platform>";
			if (line.includes("Platform detected: ")) {
				return line.replace(
					/Platform detected: .*/,
					"Platform detected: <platform>",
				);
			}
			if (line.includes("• Platform: ")) {
				return line.replace(/• Platform: .*/, "• Platform: <platform>");
			}
			if (line.startsWith("Git: ")) return "Git:      <git>";
			if (line.startsWith("Nix: ")) return "Nix:      <nix>";
			if (line.includes("Temporary bootstrap tools: ")) {
				return line.replace(
					/Temporary bootstrap tools: .*/,
					"Temporary bootstrap tools: <tools>",
				);
			}
			if (line.includes("Rosetta 2 is already installed")) return "";

			return line;
		})
		.join("\n")
		.replaceAll("\n\n→ Using preset", "\n→ Using preset")
		.replaceAll(/\n{3,}/g, "\n\n");
}

async function runCli(args: string[]): Promise<CliResult> {
	const coverageDir = Deno.env.get("DOTFILES_CLI_COVERAGE_DIR");
	const denoArgs = [
		"run",
		"--allow-all",
	];

	if (coverageDir) {
		denoArgs.push(`--coverage=${coverageDir}`);
	}

	denoArgs.push(mainPath, ...args);

	const command = new Deno.Command(Deno.execPath(), {
		args: denoArgs,
		cwd: cliDir,
		env: {
			DOTFILES_DIR: repoDir,
			HOME: Deno.env.get("HOME") ?? repoDir,
			NO_COLOR: "1",
		},
		stderr: "piped",
		stdout: "piped",
	});
	const output = await command.output();
	const decoder = new TextDecoder();

	return {
		code: output.code,
		stderr: scrubOutput(
			decoder.decode(output.stderr).replaceAll(repoDir, "<repo>"),
		),
		stdout: scrubOutput(
			decoder.decode(output.stdout).replaceAll(repoDir, "<repo>"),
		),
	};
}

async function assertCliSnapshot(t: Deno.TestContext, args: string[]) {
	const result = await runCli(args);

	assertEquals(result.code, 0);
	await assertSnapshot(t, result.stdout);
	assertEquals(result.stderr, "");
}

Deno.test("top-level help output is stable", async (t) => {
	await assertCliSnapshot(t, ["--help"]);
});

Deno.test("completion output is stable", async (t) => {
	await t.step("bash", async (step) => {
		await assertCliSnapshot(step, ["completion", "bash"]);
	});

	await t.step("nushell", async (step) => {
		await assertCliSnapshot(step, ["completion", "nushell"]);
	});
});

Deno.test("version output is stable", async (t) => {
	await assertCliSnapshot(t, ["version", "--verbose"]);
});

Deno.test("safe command outputs are stable", async (t) => {
	await t.step("groups list", async (step) => {
		await assertCliSnapshot(step, ["groups", "list"]);
	});

	await t.step("groups info", async (step) => {
		await assertCliSnapshot(step, ["groups", "info", "bash"]);
	});

	await t.step("setup dry run", async (step) => {
		await assertCliSnapshot(step, [
			"setup",
			"--dry-run",
			"--preset",
			"ci",
			"--skip-nix",
			"--no-confirm",
		]);
	});
});

Deno.test("invalid rebuild flag combinations fail", async (t) => {
	const result = await runCli(["rebuild", "--force"]);

	assertEquals(result.code, 1);
	await assertSnapshot(t, result.stderr);
});
