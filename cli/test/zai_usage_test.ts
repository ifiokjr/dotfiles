import { assertEquals, assertStringIncludes } from "@std/assert";
import { join } from "@std/path";
import {
	parseZaiQuota,
	refreshZaiUsage,
	ZAI_USAGE_RELATIVE,
	type ZaiQuotaWindow,
} from "../lib/zaiUsage.ts";

const NOW = new Date("2026-11-19T08:00:00.000Z");

const QUOTA_PAYLOAD = {
	code: 200,
	success: true,
	data: {
		level: "max",
		limits: [
			{
				type: "CREDIT_LIMIT",
				unit: 3,
				number: 5,
				usage: 28_000,
				currentValue: 238,
				remaining: 27_761,
				percentage: 1,
				nextResetTime: 1_795_118_471_999,
			},
			{
				type: "CREDIT_LIMIT",
				unit: 6,
				number: 1,
				usage: 140_000,
				currentValue: 6_464,
				remaining: 133_535,
				percentage: 4,
				nextResetTime: 1_795_627_530_984,
			},
		],
	},
};

function jsonResponse(body: unknown, status = 200): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { "content-type": "application/json" },
	});
}

async function withTempHome(
	run: (homeDir: string) => Promise<void>,
): Promise<void> {
	const homeDir = await Deno.makeTempDir({ prefix: "zai-home-" });
	const previous = Deno.env.get("ZAI_CODING_PLAN_API_KEY");
	Deno.env.delete("ZAI_CODING_PLAN_API_KEY");
	try {
		await run(homeDir);
	} finally {
		if (previous !== undefined) {
			Deno.env.set("ZAI_CODING_PLAN_API_KEY", previous);
		}
		await Deno.remove(homeDir, { recursive: true });
	}
}

async function writeAuth(homeDir: string, key: string): Promise<void> {
	const dir = join(homeDir, ".local", "share", "opencode");
	await Deno.mkdir(dir, { recursive: true });
	await Deno.writeTextFile(
		join(dir, "auth.json"),
		JSON.stringify({ "zai-coding-plan": { type: "api", key } }),
	);
}

function windowIds(windows: readonly ZaiQuotaWindow[]): string[] {
	return windows.map((window) => window.id);
}

function asRecord(value: unknown): Record<string, unknown> {
	if (typeof value !== "object" || value === null || Array.isArray(value)) {
		throw new Error("Expected a JSON object");
	}
	return value as Record<string, unknown>;
}

function windowIdsFromUnknown(value: unknown): string[] {
	if (!Array.isArray(value)) throw new Error("Expected a windows array");
	return value.map((item) => {
		const window = asRecord(item);
		return typeof window.id === "string" ? window.id : "";
	});
}

Deno.test("parseZaiQuota maps the 5-hour and weekly credit windows", () => {
	const quota = parseZaiQuota(QUOTA_PAYLOAD);

	assertEquals(quota.planLevel, "max");
	assertEquals(windowIds(quota.windows), ["zai_5h", "zai_weekly"]);

	const [fiveHour, weekly] = quota.windows;
	assertEquals(fiveHour.kind, "session");
	assertEquals(fiveHour.label, "Z.AI · 5-hour");
	assertEquals(fiveHour.usedPercent, 1);
	assertEquals(fiveHour.windowDurationMins, 300);
	assertEquals(fiveHour.resetsAt, "2026-11-19T20:01:11.999Z");
	assertEquals(fiveHour.providerIds, ["zai-coding-plan"]);

	assertEquals(weekly.kind, "weekly");
	assertEquals(weekly.usedPercent, 4);
	assertEquals(weekly.windowDurationMins, 10_080);
	assertEquals(weekly.resetsAt, "2026-11-25T17:25:30.984Z");
});

Deno.test("parseZaiQuota computes percentages and ignores unusable limits", () => {
	const quota = parseZaiQuota({
		data: {
			limits: [
				{ type: "CREDIT_LIMIT", unit: 3, usage: 1_000, currentValue: 250 },
				{ type: "CREDIT_LIMIT", unit: 6, percentage: 4.5 },
				{ type: "CREDIT_LIMIT", unit: 7, percentage: 90 },
				{ type: "CREDIT_LIMIT", unit: 3, percentage: 99 },
				{ type: "TIME_LIMIT", percentage: 12 },
				"not a limit",
			],
		},
	});

	assertEquals(quota.planLevel, null);
	assertEquals(windowIds(quota.windows), ["zai_5h", "zai_weekly"]);
	assertEquals(quota.windows[0].usedPercent, 25);
	assertEquals(quota.windows[1].usedPercent, 4.5);
	assertEquals(quota.windows[0].resetsAt, undefined);

	// Legacy plans report only the 5-hour token percentage.
	const legacy = parseZaiQuota({
		data: { limits: [{ type: "TOKENS_LIMIT", percentage: 12 }] },
	});
	assertEquals(windowIds(legacy.windows), ["zai_5h"]);
	assertEquals(legacy.windows[0].usedPercent, 12);

	// Values are clamped, and a missing total cannot produce a percentage.
	const clamped = parseZaiQuota({
		data: {
			limits: [
				{ type: "CREDIT_LIMIT", unit: 3, percentage: 140 },
				{ type: "CREDIT_LIMIT", unit: 6, usage: 0, currentValue: 10 },
			],
		},
	});
	assertEquals(clamped.windows[0].usedPercent, 100);
	assertEquals(clamped.windows.length, 1);

	assertEquals(parseZaiQuota(null), { planLevel: null, windows: [] });
	assertEquals(parseZaiQuota({ data: "nope" }), {
		planLevel: null,
		windows: [],
	});
	assertEquals(parseZaiQuota({ data: { level: "  ", limits: [] } }), {
		planLevel: null,
		windows: [],
	});
});

Deno.test("refreshZaiUsage writes the cache and honours the TTL", async () => {
	await withTempHome(async (homeDir) => {
		await writeAuth(homeDir, "test-key");
		let calls = 0;
		const fetchImpl: typeof fetch = () => {
			calls += 1;
			return Promise.resolve(jsonResponse(QUOTA_PAYLOAD));
		};
		const cachePath = join(homeDir, ZAI_USAGE_RELATIVE);

		const written = await refreshZaiUsage({
			homeDir,
			now: NOW,
			fetchImpl,
		});
		assertEquals(written.status, "written");
		assertEquals(calls, 1);
		assertEquals(
			written.status === "written" ? written.planLevel : null,
			"max",
		);

		const cache: unknown = JSON.parse(await Deno.readTextFile(cachePath));
		const record = asRecord(cache);
		assertEquals(record.instanceId, "opencode");
		assertEquals(record.planLevel, "max");
		const usage = asRecord(record.usageLimits);
		assertEquals(usage.checkedAt, NOW.toISOString());
		assertEquals(windowIdsFromUnknown(usage.windows), [
			"zai_5h",
			"zai_weekly",
		]);

		const fresh = await refreshZaiUsage({
			homeDir,
			now: new Date(NOW.getTime() + 60_000),
			fetchImpl,
		});
		assertEquals(fresh.status, "fresh");
		assertEquals(calls, 1);

		const forced = await refreshZaiUsage({
			homeDir,
			now: new Date(NOW.getTime() + 60_000),
			force: true,
			fetchImpl,
		});
		assertEquals(forced.status, "written");
		assertEquals(calls, 2);
	});
});

Deno.test("refreshZaiUsage uses the env override and reports missing credentials", async () => {
	await withTempHome(async (homeDir) => {
		const missing = await refreshZaiUsage({
			homeDir,
			now: NOW,
			fetchImpl: () => Promise.reject(new Error("must not fetch")),
		});
		assertEquals(missing.status, "no-credential");

		// OAuth credentials carry no coding-plan key, so they are not usable here.
		const authDir = join(homeDir, ".local", "share", "opencode");
		await Deno.mkdir(authDir, { recursive: true });
		await Deno.writeTextFile(
			join(authDir, "auth.json"),
			JSON.stringify({ "zai-coding-plan": { type: "oauth", access: "x" } }),
		);
		assertEquals(
			(await refreshZaiUsage({ homeDir, now: NOW })).status,
			"no-credential",
		);

		Deno.env.set("ZAI_CODING_PLAN_API_KEY", "env-key");
		let authorization: string | null = null;
		const fetchImpl: typeof fetch = (_input, init) => {
			const headers = new Headers(init?.headers);
			authorization = headers.get("Authorization");
			return Promise.resolve(jsonResponse(QUOTA_PAYLOAD));
		};
		const written = await refreshZaiUsage({ homeDir, now: NOW, fetchImpl });
		assertEquals(written.status, "written");
		assertEquals(authorization, "env-key");
	});
});

Deno.test("refreshZaiUsage preserves the previous cache when a refresh fails", async () => {
	await withTempHome(async (homeDir) => {
		await writeAuth(homeDir, "test-key");
		const cachePath = join(homeDir, ZAI_USAGE_RELATIVE);
		await refreshZaiUsage({
			homeDir,
			now: NOW,
			fetchImpl: () => Promise.resolve(jsonResponse(QUOTA_PAYLOAD)),
		});
		const before = await Deno.readTextFile(cachePath);

		const failed: Array<
			(input: string | URL | Request, init?: RequestInit) => Promise<Response>
		> = [
			() => Promise.reject(new Error("socket closed")),
			() => Promise.resolve(jsonResponse({}, 500)),
			() => Promise.resolve(jsonResponse({ data: { limits: [] } })),
		];

		for (const fetchImpl of failed) {
			const result = await refreshZaiUsage({
				homeDir,
				now: new Date(NOW.getTime() + 60_000),
				force: true,
				fetchImpl,
			});
			assertEquals(result.status, "failed");
			if (result.status === "failed") {
				assertStringIncludes(result.message, "Z.AI");
				assertEquals(result.message.includes("test-key"), false);
			}
			assertEquals(await Deno.readTextFile(cachePath), before);
		}
	});
});

Deno.test("refreshZaiUsage repairs a corrupt cache instead of trusting it", async () => {
	await withTempHome(async (homeDir) => {
		await writeAuth(homeDir, "test-key");
		const cachePath = join(homeDir, ZAI_USAGE_RELATIVE);
		await Deno.mkdir(join(homeDir, ".config", "agents", "usage"), {
			recursive: true,
		});
		await Deno.writeTextFile(cachePath, "{ not json");

		const result = await refreshZaiUsage({
			homeDir,
			now: NOW,
			fetchImpl: () => Promise.resolve(jsonResponse(QUOTA_PAYLOAD)),
		});
		assertEquals(result.status, "written");
	});
});
