import { assertEquals, assertStringIncludes, assertThrows } from "@std/assert";
import { dirname, fromFileUrl, join } from "@std/path";
import {
	evaluateCandidate,
	formatCandidateOptions,
	formatPercent,
	formatResetCountdown,
	mergeLocalModelsToml,
	MODELS_CONFIG_RELATIVE,
	parseModelsToml,
	parseProviderCacheJson,
	pickModelForTier,
	type ProviderUsageSnapshot,
	readModelsConfig,
	readProviderUsageSnapshots,
	renderStatusReport,
	resolveAllTiers,
	resolveCouncil,
} from "../lib/models.ts";

const cliDir = dirname(dirname(fromFileUrl(import.meta.url)));
const repoDir = dirname(cliDir);

const NOW = new Date("2026-11-19T08:00:00.000Z");

const SAMPLE_TOML = `
[thresholds]
low_percent = 80
exhausted_percent = 95
stale_minutes = 60

[bans]
models = ["opencode-go/deepseek-v4-pro"]
explicit_only = ["gpt-6-astra"]
reduced = ["zai-coding-plan/glm-5.3"]

[council]
description = "Three providers"

[[council.members]]
provider = "antigravity"
model = "gemini-4-neon"
usage_windows = ["gemini-5h", "gemini-weekly"]
note = "Google"

[council.members.options]
thought_level = "high"

[[council.members]]
provider = "claudeAgent"
model = "claude-opus-5-5"
usage_windows = ["seven_day"]
note = "Anthropic"

[council.members.options]
effort = "high"

[tiers.implement]
description = "Well-defined coding"

[[tiers.implement.candidates]]
provider = "opencode"
model = "opencode-go/deepseek-v4.1-flash"
usage_windows = ["go_rolling", "go_weekly", "go_monthly"]
note = "Sub 1"

[tiers.implement.candidates.options]
variant = "max"

[[tiers.implement.candidates]]
provider = "opencode-go-2"
model = "opencode-go/deepseek-v4.1-flash"
usage_windows = ["go_rolling", "go_weekly", "go_monthly"]
note = "Sub 2"

[tiers.implement.candidates.options]
variant = "max"

[[tiers.implement.candidates]]
provider = "opencode"
model = "zai-coding-plan/glm-5.3-flash"
usage_windows = []
note = "ZAI subscription"

[tiers.implement.candidates.options]
variant = "max"

[tiers.judgment]
description = "Hard reasoning"

[[tiers.judgment.candidates]]
provider = "antigravity"
model = "gemini-4-neon"
usage_windows = ["gemini-5h", "gemini-weekly"]
note = "Ultra"

[tiers.judgment.candidates.options]
thought_level = "xhigh"

[[tiers.judgment.candidates]]
provider = "claudeAgent"
model = "claude-opus-5-5"
usage_windows = ["seven_day"]
note = "Fallback"

[tiers.judgment.candidates.options]
effort = "xhigh"
`;

Deno.test("checked-in models.toml parses cleanly and obeys policy invariants", async () => {
	const { config, configPath } = await readModelsConfig(repoDir, "/nonexistent");

	assertEquals(configPath, join(repoDir, MODELS_CONFIG_RELATIVE));
	assertEquals(config.thresholds.lowPercent, 80);
	assertEquals(config.thresholds.exhaustedPercent, 95);
	assertEquals(config.council.members.length, 3);

	const expectedTiers = [
		"simple",
		"implement",
		"computer-use",
		"long-horizon",
		"judgment",
		"review",
		"design",
		"orchestrate",
	];
	for (const tier of expectedTiers) {
		assertEquals(
			Boolean(config.tiers[tier] && config.tiers[tier].candidates.length > 0),
			true,
			`Expected non-empty tier '${tier}'`,
		);
	}

	assertEquals(config.tiers.simple.candidates[0].model, "gemini-4-hydrogen");
	assertEquals(config.tiers.judgment.candidates[0].model, "gemini-4-neon");
	assertEquals(config.tiers["computer-use"].candidates[0].model, "gpt-6.1-terra");
	assertEquals(
		config.tiers.implement.candidates[0].model,
		"opencode-go/deepseek-v4.1-flash",
	);
	assertEquals(config.tiers.implement.candidates[1].provider, "opencode-go-2");
	assertEquals(config.tiers.design.candidates[0].model, "claude-opus-5-5");

	// Reduced GLM 5.3 must not appear as a default candidate in any tier.
	const reduced = new Set(config.bans.reduced);
	for (const tier of Object.values(config.tiers)) {
		for (const candidate of tier.candidates) {
			assertEquals(
				reduced.has(candidate.model),
				false,
				`Reduced model '${candidate.model}' should not be in tier '${tier.name}'`,
			);
		}
	}
});

Deno.test("parseModelsToml rejects banned models and invalid thresholds", () => {
	assertThrows(
		() =>
			parseModelsToml(`
[bans]
models = ["opencode-go/deepseek-v4-pro"]

[tiers.implement]
description = "Bad"

[[tiers.implement.candidates]]
provider = "opencode"
model = "opencode-go/deepseek-v4-pro"
`),
		Error,
		"Banned model",
	);

	assertThrows(
		() =>
			parseModelsToml(`
[bans]
models = ["opencode-go/deepseek-v4-pro"]

[council]
[[council.members]]
provider = "opencode"
model = "opencode-go/deepseek-v4-pro"
`),
		Error,
		"cannot appear in council",
	);

	assertThrows(
		() =>
			parseModelsToml(`
[thresholds]
low_percent = 95
exhausted_percent = 80
`),
		Error,
		"cannot exceed",
	);

	assertThrows(
		() => parseModelsToml(`[thresholds]\nlow_percent = 0\n`),
		Error,
		"between 1 and 100",
	);

	assertThrows(
		() => parseModelsToml(`disabled_providers = "codex"`),
		Error,
		"must be an array",
	);

	assertThrows(
		() =>
			parseModelsToml(`
[tiers.bad]
[[tiers.bad.candidates]]
provider = ""
model = "x"
`),
		Error,
		"provider",
	);

	assertThrows(
		() =>
			parseModelsToml(`
[tiers.bad]
[[tiers.bad.candidates]]
provider = "opencode"
model = ""
`),
		Error,
		"model",
	);

	assertThrows(
		() =>
			parseModelsToml(`
[tiers.bad]
[[tiers.bad.candidates]]
provider = "opencode"
model = "x"
note = 42
`),
		Error,
		"note",
	);

	assertThrows(
		() =>
			parseModelsToml(`
[tiers.bad]
[[tiers.bad.candidates]]
provider = "opencode"
model = "x"
options = "nope"
`),
		Error,
		"options",
	);

	assertThrows(
		() =>
			parseModelsToml(`
[tiers.bad]
[[tiers.bad.candidates]]
provider = "opencode"
model = "x"
[tiers.bad.candidates.options]
nested = ["a"]
`),
		Error,
		"string, number, or boolean",
	);

	assertThrows(
		() => parseModelsToml(`tiers = "bad"`),
		Error,
		"'tiers' must be a table",
	);

	assertThrows(
		() => parseModelsToml(`[tiers]\nbad = "nope"`),
		Error,
		"'tiers.bad' must be a table",
	);

	assertThrows(
		() => parseModelsToml(`[tiers.bad]\ncandidates = "nope"`),
		Error,
		"must be an array",
	);

	assertThrows(
		() => parseModelsToml(`disabled_providers = [""]`),
		Error,
		"non-empty strings",
	);

	assertThrows(
		() => parseModelsToml(`[thresholds]\nlow_percent = "80"`),
		Error,
		"finite number",
	);
});

Deno.test("mergeLocalModelsToml overrides thresholds, disabled providers, bans, council, and tiers", () => {
	const base = parseModelsToml(SAMPLE_TOML);
	const merged = mergeLocalModelsToml(
		base,
		`
disabled_providers = ["antigravity"]

[thresholds]
low_percent = 70
exhausted_percent = 90
stale_minutes = 30

[bans]
models = ["opencode-go/deepseek-v4-pro", "bad/model"]
explicit_only = ["gpt-6-astra"]
reduced = []

[council]
description = "Local council"

[tiers.judgment]
description = "Overridden judgment"
`,
	);

	assertEquals(merged.thresholds, {
		lowPercent: 70,
		exhaustedPercent: 90,
		staleMinutes: 30,
	});
	assertEquals(merged.disabledProviders, ["antigravity"]);
	assertEquals(merged.bans.models, ["opencode-go/deepseek-v4-pro", "bad/model"]);
	assertEquals(merged.bans.reduced, []);
	assertEquals(merged.council.description, "Local council");
	assertEquals(merged.council.members.length, 2);
	assertEquals(merged.tiers.judgment.description, "Overridden judgment");
	assertEquals(merged.tiers.judgment.candidates.length, 2);

	assertThrows(
		() =>
			mergeLocalModelsToml(
				base,
				`
[thresholds]
low_percent = 99
exhausted_percent = 90
`,
			),
		Error,
		"cannot exceed",
	);

	assertThrows(
		() => mergeLocalModelsToml(base, `tiers = "nope"`),
		Error,
		"'tiers' must be a table",
	);

	assertThrows(
		() => mergeLocalModelsToml(base, `[tiers]\njudgment = "nope"`),
		Error,
		"'tiers.judgment' must be a table",
	);
});

Deno.test("readModelsConfig merges deployed config and local override from HOME", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "models-cfg-" });
	const homeDir = join(tempDir, "home");
	const emptyRepo = join(tempDir, "empty-repo");
	const agentsDir = join(homeDir, ".config", "agents");

	try {
		await Deno.mkdir(agentsDir, { recursive: true });
		await Deno.mkdir(emptyRepo, { recursive: true });
		await Deno.writeTextFile(join(agentsDir, "models.toml"), SAMPLE_TOML);
		await Deno.writeTextFile(
			join(agentsDir, "models.local.toml"),
			`disabled_providers = ["opencode"]\n`,
		);

		const loaded = await readModelsConfig(emptyRepo, homeDir);
		assertEquals(loaded.configPath, join(agentsDir, "models.toml"));
		assertEquals(loaded.localOverridePath, join(agentsDir, "models.local.toml"));
		assertEquals(loaded.config.disabledProviders, ["opencode"]);

		// Missing everywhere throws a clear error.
		let threw = false;
		try {
			await readModelsConfig(emptyRepo, join(tempDir, "missing-home"));
		} catch (error) {
			threw = true;
			assertStringIncludes(
				error instanceof Error ? error.message : String(error),
				"Model routing config not found",
			);
		}
		assertEquals(threw, true);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("parseProviderCacheJson handles resets, staleness, and malformed payloads", () => {
	assertEquals(parseProviderCacheJson("x", null, 60, NOW), null);

	const snapshot = parseProviderCacheJson(
		"opencode",
		{
			instanceId: "opencode",
			displayName: "OpenCode",
			enabled: true,
			status: "ready",
			checkedAt: "2026-11-19T06:00:00.000Z",
			usageLimits: {
				checkedAt: "2026-11-19T06:30:00.000Z",
				windows: [
					{
						id: "go_rolling",
						kind: "session",
						label: "Go · Session",
						usedPercent: 92,
						resetsAt: "2026-11-19T07:30:00.000Z", // already reset before NOW
						windowDurationMins: 300,
					},
					{
						id: "go_monthly",
						kind: "monthly",
						label: "Go · Monthly",
						usedPercent: 83,
						resetsAt: "2026-12-07T10:40:56.000Z",
					},
					{ id: "bad_entry" },
				],
			},
		},
		60,
		NOW,
	);

	assertEquals(snapshot?.stale, true);
	assertEquals(snapshot?.windows.length, 2);
	assertEquals(snapshot?.windows[0].hasReset, true);
	assertEquals(snapshot?.windows[0].effectiveUsedPercent, 0);
	assertEquals(snapshot?.windows[1].hasReset, false);
	assertEquals(snapshot?.windows[1].effectiveUsedPercent, 83);
});

Deno.test("readProviderUsageSnapshots loads valid JSON files and skips malformed ones", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "t3-caches-" });

	try {
		// Missing dir returns empty map.
		const missing = await readProviderUsageSnapshots(
			join(tempDir, "nope"),
			60,
			NOW,
		);
		assertEquals(missing.size, 0);

		await Deno.writeTextFile(
			join(tempDir, "antigravity.json"),
			JSON.stringify({
				instanceId: "antigravity",
				displayName: "Antigravity",
				enabled: true,
				status: "ready",
				checkedAt: "2026-11-19T07:55:00.000Z",
				usageLimits: {
					checkedAt: "2026-11-19T07:55:00.000Z",
					windows: [
						{
							id: "gemini-5h",
							label: "Gemini · 5-hour",
							kind: "session",
							usedPercent: 1.2,
							resetsAt: "2026-11-19T11:00:00.000Z",
						},
					],
				},
			}),
		);
		await Deno.writeTextFile(join(tempDir, "corrupt.json"), "{ not json");
		await Deno.writeTextFile(join(tempDir, "README.txt"), "ignored");

		const snapshots = await readProviderUsageSnapshots(tempDir, 60, NOW);
		assertEquals(snapshots.size, 1);
		assertEquals(snapshots.get("antigravity")?.stale, false);
		assertEquals(snapshots.get("antigravity")?.windows[0].effectiveUsedPercent, 1.2);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("readProviderUsageSnapshots merges usage overlays into existing providers", async () => {
	const tempDir = await Deno.makeTempDir({ prefix: "usage-merge-" });
	const t3Dir = join(tempDir, "t3");
	const usageDir = join(tempDir, "usage");

	try {
		await Deno.mkdir(t3Dir, { recursive: true });
		await Deno.mkdir(usageDir, { recursive: true });
		await Deno.writeTextFile(
			join(t3Dir, "opencode.json"),
			JSON.stringify({
				instanceId: "opencode",
				displayName: "OpenCode",
				enabled: true,
				status: "ready",
				checkedAt: "2026-11-19T07:55:00.000Z",
				usageLimits: {
					checkedAt: "2026-11-19T07:55:00.000Z",
					windows: [
						{
							id: "go_rolling",
							label: "Go · Session",
							kind: "session",
							usedPercent: 0,
						},
						{
							id: "go_monthly",
							label: "Go · Monthly",
							kind: "monthly",
							usedPercent: 84,
						},
					],
				},
			}),
		);
		await Deno.writeTextFile(
			join(usageDir, "zai-coding-plan.json"),
			JSON.stringify({
				instanceId: "opencode",
				displayName: "Z.AI Coding Plan",
				enabled: true,
				status: "ready",
				checkedAt: "2026-11-19T06:00:00.000Z",
				usageLimits: {
					checkedAt: "2026-11-19T06:00:00.000Z",
					windows: [
						{
							id: "go_rolling",
							label: "Overridden",
							kind: "session",
							usedPercent: 12,
						},
						{
							id: "zai_5h",
							label: "Z.AI · 5-hour",
							kind: "session",
							usedPercent: 96,
						},
						{
							id: "zai_weekly",
							label: "Z.AI · Weekly",
							kind: "weekly",
							usedPercent: 4,
						},
					],
				},
			}),
		);
		// A provider T3 never reported must not appear just because an overlay exists.
		await Deno.writeTextFile(
			join(usageDir, "ghost.json"),
			JSON.stringify({
				instanceId: "ghost",
				enabled: true,
				status: "ready",
				usageLimits: { windows: [{ id: "ghost_window", usedPercent: 1 }] },
			}),
		);

		const snapshots = await readProviderUsageSnapshots(
			t3Dir,
			60,
			NOW,
			usageDir,
		);
		assertEquals(snapshots.has("ghost"), false);

		const opencode = snapshots.get("opencode");
		assertEquals(opencode?.displayName, "OpenCode");
		assertEquals(opencode?.windows.map((window) => window.id), [
			"go_rolling",
			"go_monthly",
			"zai_5h",
			"zai_weekly",
		]);
		assertEquals(opencode?.windows[0].effectiveUsedPercent, 12);
		assertEquals(opencode?.windows[0].label, "Overridden");
		assertEquals(opencode?.windows[2].effectiveUsedPercent, 96);
		// The overlay is older than the TTL, so the merged snapshot is stale.
		assertEquals(opencode?.stale, true);
	} finally {
		await Deno.remove(tempDir, { recursive: true });
	}
});

Deno.test("evaluateCandidate gates Z.AI candidates on Z.AI quota windows", () => {
	const thresholds = {
		lowPercent: 80,
		exhaustedPercent: 95,
		staleMinutes: 60,
	};
	const candidate = {
		provider: "opencode",
		model: "zai-coding-plan/glm-5.3-flash",
		options: {},
		usageWindows: ["zai_5h", "zai_weekly"],
		note: "",
	};
	const snapshot = parseProviderCacheJson(
		"opencode",
		{
			instanceId: "opencode",
			enabled: true,
			status: "ready",
			checkedAt: "2026-11-19T07:55:00.000Z",
			usageLimits: {
				checkedAt: "2026-11-19T07:55:00.000Z",
				windows: [
					{
						id: "zai_5h",
						label: "Z.AI · 5-hour",
						kind: "session",
						usedPercent: 96,
						resetsAt: "2026-11-19T20:01:11.999Z",
					},
					{
						id: "zai_weekly",
						label: "Z.AI · Weekly",
						kind: "weekly",
						usedPercent: 4,
						resetsAt: "2026-11-25T17:25:30.984Z",
					},
				],
			},
		},
		60,
		NOW,
	)!;

	const exhausted = evaluateCandidate(candidate, snapshot, thresholds);
	assertEquals(exhausted.health, "exhausted");
	assertEquals(exhausted.bottleneck?.id, "zai_5h");

	const relaxed = parseProviderCacheJson(
		"opencode",
		{
			instanceId: "opencode",
			enabled: true,
			status: "ready",
			checkedAt: "2026-11-19T07:55:00.000Z",
			usageLimits: {
				checkedAt: "2026-11-19T07:55:00.000Z",
				windows: [
					{ id: "zai_5h", label: "Z.AI · 5-hour", usedPercent: 50 },
					{ id: "zai_weekly", label: "Z.AI · Weekly", usedPercent: 4 },
				],
			},
		},
		60,
		NOW,
	)!;
	assertEquals(evaluateCandidate(candidate, relaxed, thresholds).health, "ok");
});

Deno.test("pickModelForTier routes around low/exhausted providers and falls back cleanly", () => {
	const config = parseModelsToml(SAMPLE_TOML);
	const snapshots = new Map<string, ProviderUsageSnapshot>([
		[
			"opencode",
			parseProviderCacheJson(
				"opencode",
				{
					instanceId: "opencode",
					displayName: "OpenCode",
					enabled: true,
					status: "ready",
					checkedAt: "2026-11-19T07:55:00.000Z",
					usageLimits: {
						checkedAt: "2026-11-19T07:55:00.000Z",
						windows: [
							{
								id: "go_rolling",
								label: "Go · Session",
								usedPercent: 2,
								resetsAt: "2026-11-19T11:00:00.000Z",
							},
							{
								id: "go_monthly",
								label: "Go · Monthly",
								usedPercent: 83,
								resetsAt: "2026-12-07T00:00:00.000Z",
							},
						],
					},
				},
				60,
				NOW,
			)!,
		],
		[
			"opencode-go-2",
			parseProviderCacheJson(
				"opencode-go-2",
				{
					instanceId: "opencode-go-2",
					displayName: "OpenCode Go (2nd sub)",
					enabled: true,
					status: "ready",
					checkedAt: "2026-11-19T07:55:00.000Z",
					usageLimits: {
						checkedAt: "2026-11-19T07:55:00.000Z",
						windows: [
							{ id: "go_rolling", label: "Go · Session", usedPercent: 0 },
							{ id: "go_monthly", label: "Go · Monthly", usedPercent: 0 },
						],
					},
				},
				60,
				NOW,
			)!,
		],
		[
			"antigravity",
			parseProviderCacheJson(
				"antigravity",
				{
					instanceId: "antigravity",
					displayName: "Antigravity",
					enabled: true,
					status: "ready",
					checkedAt: "2026-11-19T07:55:00.000Z",
					usageLimits: {
						checkedAt: "2026-11-19T07:55:00.000Z",
						windows: [
							{ id: "gemini-5h", label: "Gemini · 5-hour", usedPercent: 96 },
							{ id: "3p-5h", label: "Claude & GPT · 5-hour", usedPercent: 0 },
						],
					},
				},
				60,
				NOW,
			)!,
		],
		[
			"claudeAgent",
			parseProviderCacheJson(
				"claudeAgent",
				{
					instanceId: "claudeAgent",
					displayName: "Claude",
					enabled: true,
					status: "ready",
					checkedAt: "2026-11-19T07:55:00.000Z",
					usageLimits: {
						checkedAt: "2026-11-19T07:55:00.000Z",
						windows: [
							{ id: "seven_day", label: "Weekly", usedPercent: 85 },
						],
					},
				},
				60,
				NOW,
			)!,
		],
	]);

	// opencode is low (83% monthly), so implement automatically selects opencode-go-2!
	const implement = pickModelForTier("implement", config, snapshots);
	assertEquals(implement.selected?.candidate.provider, "opencode-go-2");
	assertEquals(implement.usedLowFallback, false);
	assertEquals(implement.evaluations[0].health, "low");
	assertEquals(implement.evaluations[1].health, "ok");
	// Empty usage_windows for zai-coding-plan stays ok even though opencode Go is low.
	assertEquals(implement.evaluations[2].health, "ok");

	// Excluding opencode-go-2 routes implement to unmetered zai-coding-plan/glm-5.3-flash.
	const implementExcluded = pickModelForTier("implement", config, snapshots, [
		"opencode-go-2",
	]);
	assertEquals(
		implementExcluded.selected?.candidate.model,
		"zai-coding-plan/glm-5.3-flash",
	);

	// antigravity is exhausted (96% on gemini-5h, ignoring 3p-5h); claudeAgent is low (85%) -> low fallback.
	const judgment = pickModelForTier("judgment", config, snapshots);
	assertEquals(judgment.selected?.candidate.provider, "claudeAgent");
	assertEquals(judgment.usedLowFallback, true);
	assertEquals(judgment.evaluations[0].health, "exhausted");

	// If claudeAgent is also excluded, no candidate remains.
	const none = pickModelForTier("judgment", config, snapshots, ["claudeAgent"]);
	assertEquals(none.selected, null);

	// Unknown tier throws clearly.
	assertThrows(
		() => pickModelForTier("does-not-exist", config, snapshots),
		Error,
		"Unknown tier",
	);

	// resolveAllTiers & resolveCouncil work across the config.
	const all = resolveAllTiers(config, snapshots);
	assertEquals(all.length, 2);
	const council = resolveCouncil(config, snapshots);
	assertEquals(council.members.length, 2);
	assertEquals(council.members[0].health, "exhausted");
	assertEquals(council.members[1].health, "low");

	// Status report formats cleanly without throwing.
	const report = renderStatusReport(config, snapshots, all, NOW);
	assertStringIncludes(report, "opencode-go-2 / opencode-go/deepseek-v4.1-flash");
	assertStringIncludes(report, "[LOW FALLBACK]");
	assertStringIncludes(report, "[EXHAUSTED]");
	assertStringIncludes(report, "[LOW]");
});

Deno.test("evaluateCandidate covers disabled, missing snapshot, not-ready, and missing windows", () => {
	const config = parseModelsToml(SAMPLE_TOML);
	const candidate = config.tiers.judgment.candidates[0];

	assertEquals(
		evaluateCandidate(candidate, undefined, config.thresholds, ["antigravity"])
			.health,
		"unavailable",
	);
	assertEquals(
		evaluateCandidate(candidate, undefined, config.thresholds).health,
		"unknown",
	);

	const disabledSnap = parseProviderCacheJson(
		"antigravity",
		{ instanceId: "antigravity", enabled: false, status: "disabled" },
		60,
		NOW,
	)!;
	assertEquals(
		evaluateCandidate(candidate, disabledSnap, config.thresholds).health,
		"unavailable",
	);

	const noMatchingWindowsSnap = parseProviderCacheJson(
		"antigravity",
		{
			instanceId: "antigravity",
			enabled: true,
			status: "ready",
			usageLimits: { windows: [{ id: "other", usedPercent: 10 }] },
		},
		60,
		NOW,
	)!;
	assertEquals(
		evaluateCandidate(candidate, noMatchingWindowsSnap, config.thresholds)
			.health,
		"unknown",
	);
});

Deno.test("formatting helpers cover edge cases", () => {
	assertEquals(formatPercent(0), "0%");
	assertEquals(formatPercent(0.874), "0.9%");
	assertEquals(formatPercent(47.56), "48%");

	assertEquals(formatCandidateOptions({}), "-");
	assertEquals(
		formatCandidateOptions({ thought_level: "xhigh", fastMode: false }),
		"thought_level=xhigh, fastMode=false",
	);

	assertEquals(formatResetCountdown(null, NOW), "");
	assertEquals(formatResetCountdown("not-a-date", NOW), "");
	assertEquals(formatResetCountdown("2026-11-19T07:00:00.000Z", NOW), "reset");
	assertEquals(
		formatResetCountdown("2026-11-19T08:45:00.000Z", NOW),
		"resets in 45m",
	);
	assertEquals(
		formatResetCountdown("2026-11-19T11:00:00.000Z", NOW),
		"resets in 3h",
	);
	assertEquals(
		formatResetCountdown("2026-11-19T11:20:00.000Z", NOW),
		"resets in 3h 20m",
	);
	assertEquals(
		formatResetCountdown("2026-11-21T08:00:00.000Z", NOW),
		"resets in 2d",
	);
	assertEquals(
		formatResetCountdown("2026-11-21T13:00:00.000Z", NOW),
		"resets in 2d 5h",
	);

	// Empty snapshot report & none-available rendering.
	const config = parseModelsToml(SAMPLE_TOML);
	const emptyReport = renderStatusReport(
		config,
		new Map(),
		[
			{
				tier: "judgment",
				description: "Hard",
				selected: null,
				usedLowFallback: false,
				evaluations: [],
			},
		],
		NOW,
	);
	assertStringIncludes(emptyReport, "no enabled provider caches found");
	assertStringIncludes(emptyReport, "NONE AVAILABLE");
});
