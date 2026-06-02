import { assert } from "@std/assert";

const [lcovPath, thresholdInput] = Deno.args;

if (!lcovPath || !thresholdInput) {
	console.error(
		"Usage: deno run test/coverage_threshold.ts <lcov.info> <line-threshold>",
	);
	Deno.exit(2);
}

const threshold = Number(thresholdInput);

if (!Number.isFinite(threshold)) {
	console.error(`Invalid coverage threshold: ${thresholdInput}`);
	Deno.exit(2);
}

const lcov = await Deno.readTextFile(lcovPath);
let found = 0;
let hit = 0;

for (const line of lcov.split("\n")) {
	if (line.startsWith("LF:")) {
		found += Number(line.slice(3));
	}

	if (line.startsWith("LH:")) {
		hit += Number(line.slice(3));
	}
}

assert(found > 0, "Coverage report did not include any lines");

const coverage = (hit / found) * 100;
const formatted = coverage.toFixed(2);

console.log(`Line coverage: ${formatted}% (${hit}/${found})`);

if (coverage < threshold) {
	console.error(`Line coverage ${formatted}% is below required ${threshold}%`);
	Deno.exit(1);
}
