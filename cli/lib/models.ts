/**
 * Usage-aware model routing and T3 Code quota inspection.
 *
 * Keeps model priorities declarative (`Configs/agents/.config/agents/models.toml`,
 * deployed to `~/.config/agents/models.toml`) with optional untracked machine
 * overrides (`~/.config/agents/models.local.toml`) and resolves live picks
 * against T3 Code's provider cache snapshots (`~/.t3/caches/*.json`).
 */

import { exists } from "@std/fs";
import { join } from "@std/path";
import { parse as parseToml } from "@std/toml";

/** Tracked routing manifest inside the dotfiles repo. */
export const MODELS_CONFIG_RELATIVE =
	"Configs/agents/.config/agents/models.toml";

/** Deployed user-level routing manifest under HOME. */
export const DEPLOYED_MODELS_CONFIG_RELATIVE = ".config/agents/models.toml";

/** Untracked per-machine overrides under HOME. */
export const LOCAL_MODELS_CONFIG_RELATIVE = ".config/agents/models.local.toml";

/** Default T3 Code provider caches directory under HOME. */
export const T3_CACHES_RELATIVE = ".t3/caches";

/** Usage snapshots written by this CLI (`dot models refresh`) under HOME. */
export const AGENT_USAGE_RELATIVE = ".config/agents/usage";

export interface UsageThresholds {
	lowPercent: number;
	exhaustedPercent: number;
	staleMinutes: number;
}

export interface ModelBans {
	models: string[];
	explicitOnly: string[];
	reduced: string[];
}

export interface ModelCandidate {
	provider: string;
	model: string;
	options: Record<string, string | boolean | number>;
	usageWindows: string[];
	note: string;
}

export interface ModelTier {
	name: string;
	description: string;
	candidates: ModelCandidate[];
}

export interface CouncilConfig {
	description: string;
	members: ModelCandidate[];
}

export interface ModelsConfig {
	thresholds: UsageThresholds;
	disabledProviders: string[];
	bans: ModelBans;
	council: CouncilConfig;
	tiers: Record<string, ModelTier>;
}

export interface UsageWindowSnapshot {
	id: string;
	label: string;
	kind: string;
	rawUsedPercent: number;
	effectiveUsedPercent: number;
	resetsAt: string | null;
	hasReset: boolean;
	windowDurationMins: number | null;
}

export interface ProviderUsageSnapshot {
	instanceId: string;
	displayName: string;
	enabled: boolean;
	status: string;
	checkedAt: string | null;
	usageCheckedAt: string | null;
	stale: boolean;
	windows: UsageWindowSnapshot[];
}

export type CandidateHealth =
	| "ok"
	| "low"
	| "exhausted"
	| "unavailable"
	| "unknown";

export interface CandidateEvaluation {
	candidate: ModelCandidate;
	health: CandidateHealth;
	maxUsedPercent: number | null;
	bottleneck: UsageWindowSnapshot | null;
	stale: boolean;
	reason: string;
}

export interface TierResolution {
	tier: string;
	description: string;
	selected: CandidateEvaluation | null;
	usedLowFallback: boolean;
	evaluations: CandidateEvaluation[];
}

export interface CouncilResolution {
	description: string;
	members: CandidateEvaluation[];
}

const DEFAULT_THRESHOLDS: UsageThresholds = {
	lowPercent: 80,
	exhaustedPercent: 95,
	staleMinutes: 60,
};

function isRecord(value: unknown): value is Record<string, unknown> {
	return typeof value === "object" && value !== null && !Array.isArray(value);
}

function readStringArray(value: unknown, field: string): string[] {
	if (value === undefined) return [];
	if (!Array.isArray(value)) {
		throw new Error(`Invalid models.toml: '${field}' must be an array`);
	}

	const items: string[] = [];
	for (const entry of value) {
		if (typeof entry !== "string" || entry.trim() === "") {
			throw new Error(
				`Invalid models.toml: '${field}' entries must be non-empty strings`,
			);
		}
		items.push(entry.trim());
	}
	return items;
}

function readNumber(
	value: unknown,
	fallback: number,
	field: string,
	min: number,
	max: number,
): number {
	if (value === undefined) return fallback;
	if (typeof value !== "number" || !Number.isFinite(value)) {
		throw new Error(`Invalid models.toml: '${field}' must be a finite number`);
	}
	if (value < min || value > max) {
		throw new Error(
			`Invalid models.toml: '${field}' must be between ${min} and ${max}`,
		);
	}
	return value;
}

function parseOptions(
	value: unknown,
	context: string,
): Record<string, string | boolean | number> {
	if (value === undefined) return {};
	if (!isRecord(value)) {
		throw new Error(`Invalid models.toml: '${context}.options' must be a table`);
	}

	const options: Record<string, string | boolean | number> = {};
	for (const [key, entry] of Object.entries(value)) {
		if (
			typeof entry !== "string" &&
			typeof entry !== "boolean" &&
			typeof entry !== "number"
		) {
			throw new Error(
				`Invalid models.toml: '${context}.options.${key}' must be a string, number, or boolean`,
			);
		}
		options[key] = entry;
	}
	return options;
}

function parseCandidate(value: unknown, context: string): ModelCandidate {
	if (!isRecord(value)) {
		throw new Error(`Invalid models.toml: '${context}' must be a table`);
	}

	const provider = value.provider;
	const model = value.model;
	if (typeof provider !== "string" || provider.trim() === "") {
		throw new Error(
			`Invalid models.toml: '${context}.provider' must be a non-empty string`,
		);
	}
	if (typeof model !== "string" || model.trim() === "") {
		throw new Error(
			`Invalid models.toml: '${context}.model' must be a non-empty string`,
		);
	}

	const note = value.note === undefined ? "" : value.note;
	if (typeof note !== "string") {
		throw new Error(`Invalid models.toml: '${context}.note' must be a string`);
	}

	return {
		provider: provider.trim(),
		model: model.trim(),
		options: parseOptions(value.options, context),
		usageWindows: readStringArray(
			value.usage_windows,
			`${context}.usage_windows`,
		),
		note,
	};
}

function parseCandidateList(value: unknown, context: string): ModelCandidate[] {
	if (!Array.isArray(value)) {
		throw new Error(`Invalid models.toml: '${context}' must be an array`);
	}
	return value.map((item, idx) => parseCandidate(item, `${context}[${idx}]`));
}

/** Parse and validate a `models.toml` document. */
export function parseModelsToml(content: string): ModelsConfig {
	const raw = parseToml(content);
	if (!isRecord(raw)) {
		throw new Error("Invalid models.toml: expected a top-level table");
	}

	const rawThresholds = isRecord(raw.thresholds) ? raw.thresholds : {};
	const thresholds: UsageThresholds = {
		lowPercent: readNumber(
			rawThresholds.low_percent,
			DEFAULT_THRESHOLDS.lowPercent,
			"thresholds.low_percent",
			1,
			100,
		),
		exhaustedPercent: readNumber(
			rawThresholds.exhausted_percent,
			DEFAULT_THRESHOLDS.exhaustedPercent,
			"thresholds.exhausted_percent",
			1,
			100,
		),
		staleMinutes: readNumber(
			rawThresholds.stale_minutes,
			DEFAULT_THRESHOLDS.staleMinutes,
			"thresholds.stale_minutes",
			1,
			10_080,
		),
	};

	if (thresholds.lowPercent > thresholds.exhaustedPercent) {
		throw new Error(
			"Invalid models.toml: 'thresholds.low_percent' cannot exceed 'thresholds.exhausted_percent'",
		);
	}

	const disabledProviders = readStringArray(
		raw.disabled_providers,
		"disabled_providers",
	);

	const rawBans = isRecord(raw.bans) ? raw.bans : {};
	const bans: ModelBans = {
		models: readStringArray(rawBans.models, "bans.models"),
		explicitOnly: readStringArray(rawBans.explicit_only, "bans.explicit_only"),
		reduced: readStringArray(rawBans.reduced, "bans.reduced"),
	};

	const rawCouncil = isRecord(raw.council) ? raw.council : {};
	const council: CouncilConfig = {
		description: typeof rawCouncil.description === "string"
			? rawCouncil.description
			: "",
		members: rawCouncil.members === undefined
			? []
			: parseCandidateList(rawCouncil.members, "council.members"),
	};

	const tiers: Record<string, ModelTier> = {};
	if (raw.tiers !== undefined) {
		if (!isRecord(raw.tiers)) {
			throw new Error("Invalid models.toml: 'tiers' must be a table");
		}
		for (const [name, tierValue] of Object.entries(raw.tiers)) {
			if (!isRecord(tierValue)) {
				throw new Error(`Invalid models.toml: 'tiers.${name}' must be a table`);
			}
			const description = typeof tierValue.description === "string"
				? tierValue.description
				: "";
			const candidates = parseCandidateList(
				tierValue.candidates,
				`tiers.${name}.candidates`,
			);
			tiers[name] = { name, description, candidates };
		}
	}

	const config: ModelsConfig = {
		thresholds,
		disabledProviders,
		bans,
		council,
		tiers,
	};
	assertNoBannedCandidates(config);
	return config;
}

/** Merge an optional local override TOML onto a base ModelsConfig. */
export function mergeLocalModelsToml(
	base: ModelsConfig,
	localContent: string,
): ModelsConfig {
	const raw = parseToml(localContent);
	if (!isRecord(raw)) {
		throw new Error("Invalid models.local.toml: expected a top-level table");
	}

	const thresholds: UsageThresholds = { ...base.thresholds };
	if (isRecord(raw.thresholds)) {
		thresholds.lowPercent = readNumber(
			raw.thresholds.low_percent,
			thresholds.lowPercent,
			"thresholds.low_percent",
			1,
			100,
		);
		thresholds.exhaustedPercent = readNumber(
			raw.thresholds.exhausted_percent,
			thresholds.exhaustedPercent,
			"thresholds.exhausted_percent",
			1,
			100,
		);
		thresholds.staleMinutes = readNumber(
			raw.thresholds.stale_minutes,
			thresholds.staleMinutes,
			"thresholds.stale_minutes",
			1,
			10_080,
		);
	}
	if (thresholds.lowPercent > thresholds.exhaustedPercent) {
		throw new Error(
			"Invalid models.local.toml: 'thresholds.low_percent' cannot exceed 'thresholds.exhausted_percent'",
		);
	}

	const disabledProviders = raw.disabled_providers === undefined
		? [...base.disabledProviders]
		: readStringArray(raw.disabled_providers, "disabled_providers");

	const bans: ModelBans = {
		models: [...base.bans.models],
		explicitOnly: [...base.bans.explicitOnly],
		reduced: [...base.bans.reduced],
	};
	if (isRecord(raw.bans)) {
		if (raw.bans.models !== undefined) {
			bans.models = readStringArray(raw.bans.models, "bans.models");
		}
		if (raw.bans.explicit_only !== undefined) {
			bans.explicitOnly = readStringArray(
				raw.bans.explicit_only,
				"bans.explicit_only",
			);
		}
		if (raw.bans.reduced !== undefined) {
			bans.reduced = readStringArray(raw.bans.reduced, "bans.reduced");
		}
	}

	let council = base.council;
	if (isRecord(raw.council)) {
		council = {
			description: typeof raw.council.description === "string"
				? raw.council.description
				: base.council.description,
			members: raw.council.members === undefined
				? base.council.members
				: parseCandidateList(raw.council.members, "council.members"),
		};
	}

	const tiers: Record<string, ModelTier> = { ...base.tiers };
	if (raw.tiers !== undefined) {
		if (!isRecord(raw.tiers)) {
			throw new Error("Invalid models.local.toml: 'tiers' must be a table");
		}
		for (const [name, tierValue] of Object.entries(raw.tiers)) {
			if (!isRecord(tierValue)) {
				throw new Error(
					`Invalid models.local.toml: 'tiers.${name}' must be a table`,
				);
			}
			const existing = tiers[name];
			const description = typeof tierValue.description === "string"
				? tierValue.description
				: existing?.description ?? "";
			const candidates = tierValue.candidates === undefined
				? existing?.candidates ?? []
				: parseCandidateList(tierValue.candidates, `tiers.${name}.candidates`);
			tiers[name] = { name, description, candidates };
		}
	}

	const merged: ModelsConfig = {
		thresholds,
		disabledProviders,
		bans,
		council,
		tiers,
	};
	assertNoBannedCandidates(merged);
	return merged;
}

function assertNoBannedCandidates(config: ModelsConfig) {
	const banned = new Set(config.bans.models);
	if (banned.size === 0) return;

	for (const tier of Object.values(config.tiers)) {
		for (const candidate of tier.candidates) {
			if (banned.has(candidate.model)) {
				throw new Error(
					`Banned model '${candidate.model}' cannot appear in tier '${tier.name}'`,
				);
			}
		}
	}

	for (const member of config.council.members) {
		if (banned.has(member.model)) {
			throw new Error(
				`Banned model '${member.model}' cannot appear in council`,
			);
		}
	}
}

/**
 * Load the routing configuration from the dotfiles repo (or deployed `~/.config/agents/models.toml`)
 * and merge optional `~/.config/agents/models.local.toml` overrides.
 */
export async function readModelsConfig(
	dotfilesDir: string,
	homeDir?: string,
): Promise<{
	config: ModelsConfig;
	configPath: string;
	localOverridePath: string | null;
}> {
	const resolvedHome = homeDir ?? Deno.env.get("HOME") ??
		Deno.env.get("USERPROFILE") ?? "";
	const repoPath = join(dotfilesDir, MODELS_CONFIG_RELATIVE);
	const deployedPath = resolvedHome
		? join(resolvedHome, DEPLOYED_MODELS_CONFIG_RELATIVE)
		: "";

	let configPath: string;
	if (await exists(repoPath, { isFile: true })) {
		configPath = repoPath;
	} else if (deployedPath && await exists(deployedPath, { isFile: true })) {
		configPath = deployedPath;
	} else {
		throw new Error(
			`Model routing config not found at ${repoPath}${
				deployedPath ? ` or ${deployedPath}` : ""
			}`,
		);
	}

	let config = parseModelsToml(await Deno.readTextFile(configPath));
	let localOverridePath: string | null = null;

	if (resolvedHome) {
		const candidateLocal = join(resolvedHome, LOCAL_MODELS_CONFIG_RELATIVE);
		if (await exists(candidateLocal, { isFile: true })) {
			config = mergeLocalModelsToml(
				config,
				await Deno.readTextFile(candidateLocal),
			);
			localOverridePath = candidateLocal;
		}
	}

	return { config, configPath, localOverridePath };
}

/** Parse one T3 Code provider cache JSON object into a usage snapshot. */
export function parseProviderCacheJson(
	fallbackInstanceId: string,
	raw: unknown,
	staleMinutes: number,
	now: Date = new Date(),
): ProviderUsageSnapshot | null {
	if (!isRecord(raw)) return null;

	const instanceId =
		typeof raw.instanceId === "string" && raw.instanceId.trim() !== ""
			? raw.instanceId.trim()
			: fallbackInstanceId;
	const displayName =
		typeof raw.displayName === "string" && raw.displayName.trim() !== ""
			? raw.displayName.trim()
			: instanceId;
	const enabled = typeof raw.enabled === "boolean" ? raw.enabled : true;
	const status = typeof raw.status === "string" ? raw.status : "unknown";
	const checkedAt = typeof raw.checkedAt === "string" ? raw.checkedAt : null;

	const usageLimits = isRecord(raw.usageLimits) ? raw.usageLimits : null;
	const usageCheckedAt = usageLimits && typeof usageLimits.checkedAt === "string"
		? usageLimits.checkedAt
		: null;

	const freshnessTimestamp = usageCheckedAt ?? checkedAt;
	let stale = false;
	if (freshnessTimestamp) {
		const parsedMs = Date.parse(freshnessTimestamp);
		if (!Number.isNaN(parsedMs)) {
			const ageMs = now.getTime() - parsedMs;
			stale = ageMs > staleMinutes * 60_000;
		}
	}

	const windows: UsageWindowSnapshot[] = [];
	if (usageLimits && Array.isArray(usageLimits.windows)) {
		for (const item of usageLimits.windows) {
			if (!isRecord(item)) continue;
			const id = typeof item.id === "string" ? item.id : "";
			const used = typeof item.usedPercent === "number" &&
					Number.isFinite(item.usedPercent)
				? item.usedPercent
				: null;
			if (!id || used === null) continue;

			const resetsAt = typeof item.resetsAt === "string"
				? item.resetsAt
				: null;
			const resetsAtMs = resetsAt ? Date.parse(resetsAt) : Number.NaN;
			const hasReset = !Number.isNaN(resetsAtMs) &&
				resetsAtMs <= now.getTime();
			const effectiveUsedPercent = hasReset ? 0 : Math.max(0, used);

			windows.push({
				id,
				label: typeof item.label === "string" ? item.label : id,
				kind: typeof item.kind === "string" ? item.kind : "other",
				rawUsedPercent: used,
				effectiveUsedPercent,
				resetsAt,
				hasReset,
				windowDurationMins: typeof item.windowDurationMins === "number"
					? item.windowDurationMins
					: null,
			});
		}
	}

	return {
		instanceId,
		displayName,
		enabled,
		status,
		checkedAt,
		usageCheckedAt,
		stale,
		windows,
	};
}

/** Read all T3 Code provider usage snapshots from `~/.t3/caches/*.json`. */
export async function readProviderUsageSnapshots(
	t3CachesDir: string,
	staleMinutes = DEFAULT_THRESHOLDS.staleMinutes,
	now: Date = new Date(),
	usageDir?: string,
): Promise<Map<string, ProviderUsageSnapshot>> {
	const snapshots = await readSnapshotDirectory(t3CachesDir, staleMinutes, now);
	if (!usageDir) return snapshots;

	const overlays = await readSnapshotDirectory(usageDir, staleMinutes, now);
	for (const [instanceId, overlay] of overlays) {
		const base = snapshots.get(instanceId);
		// An overlay measures quota for a provider T3 already reports; it must
		// never make a provider look ready when T3 has no cache for it.
		if (!base) continue;
		snapshots.set(instanceId, mergeUsageOverlay(base, overlay));
	}
	return snapshots;
}

async function readSnapshotDirectory(
	dir: string,
	staleMinutes: number,
	now: Date,
): Promise<Map<string, ProviderUsageSnapshot>> {
	const snapshots = new Map<string, ProviderUsageSnapshot>();
	if (!await exists(dir, { isDirectory: true })) {
		return snapshots;
	}

	for await (const entry of Deno.readDir(dir)) {
		if (!entry.isFile || !entry.name.endsWith(".json")) continue;
		const fallbackId = entry.name.slice(0, -".json".length);
		const filePath = join(dir, entry.name);
		try {
			const parsed: unknown = JSON.parse(await Deno.readTextFile(filePath));
			const snapshot = parseProviderCacheJson(
				fallbackId,
				parsed,
				staleMinutes,
				now,
			);
			if (snapshot) {
				snapshots.set(snapshot.instanceId, snapshot);
			}
		} catch {
			// Ignore partially written or non-provider JSON files in the cache directory.
		}
	}

	return snapshots;
}

function mergeUsageOverlay(
	base: ProviderUsageSnapshot,
	overlay: ProviderUsageSnapshot,
): ProviderUsageSnapshot {
	const windows = new Map(base.windows.map((window) => [window.id, window]));
	for (const window of overlay.windows) windows.set(window.id, window);
	return {
		...base,
		stale: base.stale || overlay.stale,
		windows: [...windows.values()],
	};
}

/** Evaluate a single model candidate against its provider's live usage snapshot. */
export function evaluateCandidate(
	candidate: ModelCandidate,
	snapshot: ProviderUsageSnapshot | undefined,
	thresholds: UsageThresholds,
	disabledProviders: readonly string[] = [],
	excludedProviders: readonly string[] = [],
): CandidateEvaluation {
	if (disabledProviders.includes(candidate.provider)) {
		return {
			candidate,
			health: "unavailable",
			maxUsedPercent: null,
			bottleneck: null,
			stale: false,
			reason: `provider '${candidate.provider}' disabled in config`,
		};
	}

	if (excludedProviders.includes(candidate.provider)) {
		return {
			candidate,
			health: "unavailable",
			maxUsedPercent: null,
			bottleneck: null,
			stale: false,
			reason: `provider '${candidate.provider}' excluded`,
		};
	}

	if (!snapshot) {
		return {
			candidate,
			health: "unknown",
			maxUsedPercent: null,
			bottleneck: null,
			stale: false,
			reason: "no T3 cache snapshot found (assumed available)",
		};
	}

	if (!snapshot.enabled || snapshot.status !== "ready") {
		return {
			candidate,
			health: "unavailable",
			maxUsedPercent: null,
			bottleneck: null,
			stale: snapshot.stale,
			reason: `provider status is ${
				snapshot.enabled ? snapshot.status : "disabled"
			}`,
		};
	}

	// Empty usageWindows explicitly marks subscription-backed or unmetered models
	// whose quota is not tracked by any provider cache window (e.g. free Go models).
	if (candidate.usageWindows.length === 0) {
		return {
			candidate,
			health: "ok",
			maxUsedPercent: null,
			bottleneck: null,
			stale: snapshot.stale,
			reason: "ready (unmetered / external quota)",
		};
	}

	const governed = snapshot.windows.filter((window) =>
		candidate.usageWindows.includes(window.id)
	);
	if (governed.length === 0) {
		return {
			candidate,
			health: "unknown",
			maxUsedPercent: null,
			bottleneck: null,
			stale: snapshot.stale,
			reason: "ready (matching usage windows not reported)",
		};
	}

	let bottleneck = governed[0];
	for (const window of governed) {
		if (window.effectiveUsedPercent > bottleneck.effectiveUsedPercent) {
			bottleneck = window;
		}
	}

	const maxUsed = bottleneck.effectiveUsedPercent;
	const pct = formatPercent(maxUsed);
	const staleSuffix = snapshot.stale ? " (stale)" : "";

	if (maxUsed >= thresholds.exhaustedPercent) {
		return {
			candidate,
			health: "exhausted",
			maxUsedPercent: maxUsed,
			bottleneck,
			stale: snapshot.stale,
			reason: `${bottleneck.label} at ${pct}${staleSuffix}`,
		};
	}

	if (maxUsed >= thresholds.lowPercent) {
		return {
			candidate,
			health: "low",
			maxUsedPercent: maxUsed,
			bottleneck,
			stale: snapshot.stale,
			reason: `${bottleneck.label} at ${pct}${staleSuffix}`,
		};
	}

	return {
		candidate,
		health: "ok",
		maxUsedPercent: maxUsed,
		bottleneck,
		stale: snapshot.stale,
		reason: `${bottleneck.label} at ${pct}${staleSuffix}`,
	};
}

/**
 * Pick the highest-priority candidate in `tierName` that has healthy headroom.
 *
 * Pass 1 chooses the first `ok` or `unknown` candidate.
 * Pass 2 falls back to the first `low` candidate if every available candidate is low.
 * Exhausted and unavailable candidates are never selected.
 */
export function pickModelForTier(
	tierName: string,
	config: ModelsConfig,
	snapshots: ReadonlyMap<string, ProviderUsageSnapshot>,
	excludedProviders: readonly string[] = [],
): TierResolution {
	const tier = config.tiers[tierName];
	if (!tier) {
		const valid = Object.keys(config.tiers).join(", ");
		throw new Error(`Unknown tier '${tierName}'. Valid tiers: ${valid}`);
	}

	const evaluations = tier.candidates.map((candidate) =>
		evaluateCandidate(
			candidate,
			snapshots.get(candidate.provider),
			config.thresholds,
			config.disabledProviders,
			excludedProviders,
		)
	);

	const healthy = evaluations.find(
		(entry) => entry.health === "ok" || entry.health === "unknown",
	);
	if (healthy) {
		return {
			tier: tier.name,
			description: tier.description,
			selected: healthy,
			usedLowFallback: false,
			evaluations,
		};
	}

	const lowFallback = evaluations.find((entry) => entry.health === "low");
	if (lowFallback) {
		return {
			tier: tier.name,
			description: tier.description,
			selected: lowFallback,
			usedLowFallback: true,
			evaluations,
		};
	}

	return {
		tier: tier.name,
		description: tier.description,
		selected: null,
		usedLowFallback: false,
		evaluations,
	};
}

/** Resolve live picks across every configured tier in declaration order. */
export function resolveAllTiers(
	config: ModelsConfig,
	snapshots: ReadonlyMap<string, ProviderUsageSnapshot>,
	excludedProviders: readonly string[] = [],
): TierResolution[] {
	return Object.keys(config.tiers).map((tierName) =>
		pickModelForTier(tierName, config, snapshots, excludedProviders)
	);
}

/** Evaluate every member of the configured review council against live usage. */
export function resolveCouncil(
	config: ModelsConfig,
	snapshots: ReadonlyMap<string, ProviderUsageSnapshot>,
	excludedProviders: readonly string[] = [],
): CouncilResolution {
	return {
		description: config.council.description,
		members: config.council.members.map((member) =>
			evaluateCandidate(
				member,
				snapshots.get(member.provider),
				config.thresholds,
				config.disabledProviders,
				excludedProviders,
			)
		),
	};
}

/** Format a usage percentage cleanly (e.g. `0%`, `0.9%`, `83%`). */
export function formatPercent(value: number): string {
	const rounded = Math.round(value * 10) / 10;
	if (Number.isInteger(rounded) || rounded >= 10) {
		return `${Math.round(rounded)}%`;
	}
	return `${rounded.toFixed(1)}%`;
}

/** Format candidate options as a compact `k=v` string. */
export function formatCandidateOptions(
	options: Readonly<Record<string, string | boolean | number>>,
): string {
	const entries = Object.entries(options);
	if (entries.length === 0) return "-";
	return entries.map(([key, value]) => `${key}=${String(value)}`).join(", ");
}

/** Format a relative reset countdown from an ISO timestamp. */
export function formatResetCountdown(
	resetsAt: string | null,
	now: Date = new Date(),
): string {
	if (!resetsAt) return "";
	const ms = Date.parse(resetsAt);
	if (Number.isNaN(ms)) return "";

	const diffMins = Math.round((ms - now.getTime()) / 60_000);
	if (diffMins <= 0) return "reset";
	if (diffMins < 60) return `resets in ${diffMins}m`;

	const hours = Math.floor(diffMins / 60);
	const mins = diffMins % 60;
	if (hours < 24) {
		return mins > 0 ? `resets in ${hours}h ${mins}m` : `resets in ${hours}h`;
	}

	const days = Math.floor(hours / 24);
	const remHours = hours % 24;
	return remHours > 0
		? `resets in ${days}d ${remHours}h`
		: `resets in ${days}d`;
}

/** Render a concise plain-text summary of provider usage and resolved tier picks. */
export function renderStatusReport(
	config: ModelsConfig,
	snapshots: ReadonlyMap<string, ProviderUsageSnapshot>,
	resolutions: readonly TierResolution[],
	now: Date = new Date(),
): string {
	const lines: string[] = [];

	lines.push("Provider usage (T3 Code caches):");
	const enabledProviders = [...snapshots.values()]
		.filter((snapshot) => snapshot.enabled)
		.toSorted((a, b) => a.instanceId.localeCompare(b.instanceId));

	if (enabledProviders.length === 0) {
		lines.push("  (no enabled provider caches found in ~/.t3/caches)");
	} else {
		for (const snapshot of enabledProviders) {
			const staleTag = snapshot.stale ? " [stale]" : "";
			if (snapshot.windows.length === 0) {
				lines.push(
					`  ${snapshot.instanceId.padEnd(15)} ${snapshot.status}${staleTag}`,
				);
				continue;
			}

			const windowSummaries = snapshot.windows.map((window) => {
				const pct = formatPercent(window.effectiveUsedPercent);
				const countdown = formatResetCountdown(window.resetsAt, now);
				const flag = window.effectiveUsedPercent >=
						config.thresholds.exhaustedPercent
					? " [EXHAUSTED]"
					: window.effectiveUsedPercent >= config.thresholds.lowPercent
					? " [LOW]"
					: "";
				const resetNote = countdown ? ` (${countdown})` : "";
				return `${window.id}: ${pct}${flag}${resetNote}`;
			});
			lines.push(
				`  ${snapshot.instanceId.padEnd(15)} ${
					windowSummaries.join("  |  ")
				}${staleTag}`,
			);
		}
	}

	lines.push("");
	lines.push(
		`Recommended picks (low >= ${config.thresholds.lowPercent}%, skip >= ${config.thresholds.exhaustedPercent}%):`,
	);
	for (const resolution of resolutions) {
		if (!resolution.selected) {
			lines.push(`  ${resolution.tier.padEnd(13)} NONE AVAILABLE`);
			continue;
		}
		const { candidate, health, reason } = resolution.selected;
		const opts = formatCandidateOptions(candidate.options);
		const tag = resolution.usedLowFallback ? " [LOW FALLBACK]" : "";
		lines.push(
			`  ${resolution.tier.padEnd(13)} ${candidate.provider} / ${candidate.model} (${opts}) — ${health}: ${reason}${tag}`,
		);
	}

	return lines.join("\n");
}
