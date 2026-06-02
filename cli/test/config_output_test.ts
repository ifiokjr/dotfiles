import { assertEquals, assertStringIncludes } from "@std/assert";
import {
	colors,
	printError,
	printHeader,
	printInfo,
	printSuccess,
	printWarning,
} from "../lib/config.ts";

function captureOutput(fn: () => void) {
	const logs: string[] = [];
	const errors: string[] = [];
	const originalLog = console.log;
	const originalError = console.error;

	try {
		console.log = (value: unknown) => logs.push(String(value));
		console.error = (value: unknown) => errors.push(String(value));
		fn();
	} finally {
		console.log = originalLog;
		console.error = originalError;
	}

	return { errors, logs };
}

Deno.test("color helpers wrap text with ansi escapes", () => {
	assertEquals(colors.red("x"), "\x1b[0;31mx\x1b[0m");
	assertEquals(colors.green("x"), "\x1b[0;32mx\x1b[0m");
	assertEquals(colors.yellow("x"), "\x1b[1;33mx\x1b[0m");
	assertEquals(colors.blue("x"), "\x1b[0;34mx\x1b[0m");
	assertEquals(colors.cyan("x"), "\x1b[0;36mx\x1b[0m");
	assertEquals(colors.bold("x"), "\x1b[1mx\x1b[0m");
});

Deno.test("print helpers write expected channels", () => {
	const output = captureOutput(() => {
		printHeader("header");
		printSuccess("success");
		printWarning("warning");
		printInfo("info");
		printError("error");
	});

	assertEquals(output.logs.length, 4);
	assertEquals(output.errors.length, 1);
	assertStringIncludes(output.logs.join("\n"), "header");
	assertStringIncludes(output.logs.join("\n"), "success");
	assertStringIncludes(output.logs.join("\n"), "warning");
	assertStringIncludes(output.logs.join("\n"), "info");
	assertStringIncludes(output.errors.join("\n"), "error");
});
