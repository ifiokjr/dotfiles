/**
 * Z.AI coding-plan quota probing for `dot models`.
 *
 * T3 Code's OpenCode driver reports only OpenCode Go windows, so Z.AI's own
 * 5-hour and weekly credits are fetched here and cached for `dot models` to
 * merge into the OpenCode snapshot. T3 Code itself never reads this file.
 */

import { dirname, join } from "@std/path";

/** Cache file under HOME, written in T3 Code's provider-cache shape. */
export const ZAI_USAGE_RELATIVE = ".config/agents/usage/zai-coding-plan.json";

/** Official quota endpoint used by Z.AI's own `glm-plan-usage` plugin. */
export const ZAI_QUOTA_URL = "https://api.z.ai/api/monitor/usage/quota/limit";

/** Rewrite the cache at most this often; `dot models` calls this on every run. */
export const ZAI_USAGE_TTL_MINUTES = 5;

const ZAI_PROVIDER_ID = "zai-coding-plan";
const ZAI_INSTANCE_ID = "opencode";
const ZAI_API_KEY_ENV = "ZAI_CODING_PLAN_API_KEY";
const OPENCODE_AUTH_RELATIVE = ".local/share/opencode/auth.json";
const REQUEST_TIMEOUT_MS = 5_000;

/** One quota window in the shape T3 Code's provider cache uses. */
export interface ZaiQuotaWindow {
	id: string;
	kind: string;
	label: string;
	usedPercent: number;
	resetsAt?: string;
	windowDurationMins: number;
	providerIds: string[];
}

export interface ZaiQuota {
	planLevel: string | null;
	windows: ZaiQuotaWindow[];
}

export type ZaiRefreshResult =
	| { status: "fresh"; cachePath: string }
	| {
		status: "written";
		cachePath: string;
		planLevel: string | null;
		windows: ZaiQuotaWindow[];
	}
	| { status: "no-credential"; cachePath: string }
	| { status: "failed"; cachePath: string; message: string };

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function finiteNumber(value: unknown): number | null {
	return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function clampPercent(value: number): number {
	return Math.min(100, Math.max(0, Math.round(value * 100) / 100));
}

function resetIso(value: unknown): string | undefined {
	const ms = finiteNumber(value);
	if (ms === null || ms <= 0) return undefined;
	const date = new Date(ms);
	return Number.isNaN(date.getTime()) ? undefined : date.toISOString();
}

/** Percentage of the allowance used, preferring the API's own percentage. */
function creditPercent(item: Record<string, unknown>): number | null {
	const percentage = finiteNumber(item.percentage);
	if (percentage !== null) return clampPercent(percentage);

	const current = finiteNumber(item.currentValue);
	const total = finiteNumber(item.usage);
	if (current === null || total === null || total <= 0) return null;
	return clampPercent((current / total) * 100);
}

function makeWindow(
	id: "zai_5h" | "zai_weekly",
	usedPercent: number,
	resetsAt: string | undefined,
): ZaiQuotaWindow {
	const meta = id === "zai_5h"
		? { kind: "session", label: "Z.AI · 5-hour", windowDurationMins: 300 }
		: { kind: "weekly", label: "Z.AI · Weekly", windowDurationMins: 10_080 };
	return {
		id,
		...meta,
		usedPercent,
		...(resetsAt ? { resetsAt } : {}),
		providerIds: [ZAI_PROVIDER_ID],
	};
}

/**
 * Map the Z.AI quota response to T3 windows.
 *
 * `CREDIT_LIMIT` unit 3 is the 5-hour allowance and unit 6 the weekly one.
 * Older plans report `TOKENS_LIMIT` instead, which is also the 5-hour window.
 * Unknown types and units are ignored rather than failing the whole probe.
 */
export function parseZaiQuota(raw: unknown): ZaiQuota {
	const data = isRecord(raw) && isRecord(raw.data) ? raw.data : null;
	if (!data) return { planLevel: null, windows: [] };

	const planLevel = typeof data.level === "string" && data.level.trim() !== ""
		? data.level.trim()
		: null;
	const limits = Array.isArray(data.limits) ? data.limits : [];
	const windows: ZaiQuotaWindow[] = [];
	const seen = new Set<string>();

	for (const item of limits) {
		if (!isRecord(item)) continue;
		const type = typeof item.type === "string" ? item.type : "";

		if (type === "CREDIT_LIMIT") {
			const unit = finiteNumber(item.unit);
			const id = unit === 3 ? "zai_5h" : unit === 6 ? "zai_weekly" : null;
			if (!id || seen.has(id)) continue;
			const used = creditPercent(item);
			if (used === null) continue;
			seen.add(id);
			windows.push(makeWindow(id, used, resetIso(item.nextResetTime)));
			continue;
		}

		if (type === "TOKENS_LIMIT" && !seen.has("zai_5h")) {
			const used = finiteNumber(item.percentage);
			if (used === null) continue;
			seen.add("zai_5h");
			windows.push(makeWindow("zai_5h", clampPercent(used), undefined));
		}
	}

	return { planLevel, windows };
}

async function readCacheCheckedAt(cachePath: string): Promise<number | null> {
	try {
		const raw: unknown = JSON.parse(await Deno.readTextFile(cachePath));
		if (!isRecord(raw)) return null;
		const usageLimits = isRecord(raw.usageLimits) ? raw.usageLimits : null;
		const timestamp = typeof usageLimits?.checkedAt === "string"
			? usageLimits.checkedAt
			: typeof raw.checkedAt === "string"
			? raw.checkedAt
			: null;
		if (!timestamp) return null;
		const ms = Date.parse(timestamp);
		return Number.isNaN(ms) ? null : ms;
	} catch {
		return null;
	}
}

/** The coding-plan key OpenCode already stores, or an explicit env override. */
async function readZaiApiKey(homeDir: string): Promise<string | null> {
	const envKey = Deno.env.get(ZAI_API_KEY_ENV)?.trim();
	if (envKey) return envKey;

	try {
		const raw: unknown = JSON.parse(
			await Deno.readTextFile(join(homeDir, OPENCODE_AUTH_RELATIVE)),
		);
		if (!isRecord(raw)) return null;
		const entry = raw[ZAI_PROVIDER_ID];
		if (!isRecord(entry)) return null;
		// OpenCode stores API keys as "api" today; older versions used "key".
		if (
			entry.type !== undefined && entry.type !== "api" && entry.type !== "key"
		) {
			return null;
		}
		const key = typeof entry.key === "string" ? entry.key.trim() : "";
		return key === "" ? null : key;
	} catch {
		return null;
	}
}

async function writeCache(cachePath: string, body: unknown): Promise<void> {
	await Deno.mkdir(dirname(cachePath), { recursive: true });
	const tempPath = `${cachePath}.${crypto.randomUUID()}.tmp`;
	try {
		await Deno.writeTextFile(tempPath, `${JSON.stringify(body, null, 2)}\n`);
		await Deno.rename(tempPath, cachePath);
	} catch (error) {
		await Deno.remove(tempPath).catch(() => {});
		throw error;
	}
}

/**
 * Read the Z.AI quota and rewrite the cache unless it is younger than the TTL.
 *
 * Never throws and never includes the API key in a result or message: callers
 * treat a failed probe as missing data, keeping the previous cache intact.
 */
export async function refreshZaiUsage(options: {
	homeDir: string;
	now?: Date;
	force?: boolean;
	fetchImpl?: typeof fetch;
	ttlMinutes?: number;
}): Promise<ZaiRefreshResult> {
	const cachePath = join(options.homeDir, ZAI_USAGE_RELATIVE);
	const now = options.now ?? new Date();
	const ttlMinutes = options.ttlMinutes ?? ZAI_USAGE_TTL_MINUTES;

	if (!options.force) {
		const checkedAt = await readCacheCheckedAt(cachePath);
		if (checkedAt !== null && now.getTime() - checkedAt < ttlMinutes * 60_000) {
			return { status: "fresh", cachePath };
		}
	}

	const apiKey = await readZaiApiKey(options.homeDir);
	if (!apiKey) return { status: "no-credential", cachePath };

	try {
		const fetchImpl = options.fetchImpl ?? fetch;
		const response = await fetchImpl(ZAI_QUOTA_URL, {
			headers: {
				Authorization: apiKey,
				"Accept-Language": "en-US,en",
				"Content-Type": "application/json",
			},
			signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
		});
		if (!response.ok) {
			return {
				status: "failed",
				cachePath,
				message: `Z.AI quota request failed with HTTP ${response.status}.`,
			};
		}

		const body: unknown = await response.json();
		const quota = parseZaiQuota(body);
		if (quota.windows.length === 0) {
			return {
				status: "failed",
				cachePath,
				message: "Z.AI returned no usable quota windows.",
			};
		}

		const checkedAt = now.toISOString();
		await writeCache(cachePath, {
			version: 1,
			instanceId: ZAI_INSTANCE_ID,
			displayName: "OpenCode",
			enabled: true,
			status: "ready",
			checkedAt,
			planLevel: quota.planLevel,
			usageLimits: { checkedAt, windows: quota.windows },
		});

		return {
			status: "written",
			cachePath,
			planLevel: quota.planLevel,
			windows: quota.windows,
		};
	} catch (error) {
		const name = error instanceof Error ? error.name : "unknown error";
		return {
			status: "failed",
			cachePath,
			message: `Z.AI quota request failed (${name}).`,
		};
	}
}
