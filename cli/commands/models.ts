/**
 * `dotfiles models` — Inspect live provider usage and resolve usage-aware model picks.
 *
 * Reads the declarative routing policy from `models.toml` (plus optional
 * `~/.config/agents/models.local.toml`) and evaluates every candidate against
 * T3 Code's live usage caches under `~/.t3/caches/*.json`.
 */

import { Command } from "@cliffy/command";
import { join } from "@std/path";
import {
	printError,
	printHeader,
	printInfo,
	printWarning,
	resolveDotfilesDir,
} from "../lib/config.ts";
import {
	AGENT_USAGE_RELATIVE,
	formatCandidateOptions,
	formatPercent,
	formatResetCountdown,
	type ModelsConfig,
	pickModelForTier,
	type ProviderUsageSnapshot,
	readModelsConfig,
	readProviderUsageSnapshots,
	renderStatusReport,
	resolveAllTiers,
	resolveCouncil,
	T3_CACHES_RELATIVE,
} from "../lib/models.ts";
import { refreshZaiUsage } from "../lib/zaiUsage.ts";

interface SharedModelOptions {
	json?: boolean;
	cachesDir?: string;
	excludeProvider?: string[];
}

function defaultT3CachesDir(): string {
	const home = defaultHomeDir();
	return join(home, T3_CACHES_RELATIVE);
}

function defaultHomeDir(): string {
	return Deno.env.get("HOME") ?? Deno.env.get("USERPROFILE") ?? "";
}

async function loadState(opts: SharedModelOptions): Promise<{
	config: ModelsConfig;
	configPath: string;
	localOverridePath: string | null;
	snapshots: Map<string, ProviderUsageSnapshot>;
	now: Date;
}> {
	const dotfilesDir = await resolveDotfilesDir();
	let loaded: Awaited<ReturnType<typeof readModelsConfig>>;
	try {
		loaded = await readModelsConfig(dotfilesDir);
	} catch (error) {
		printError(error instanceof Error ? error.message : String(error));
		Deno.exit(1);
	}

	const now = new Date();
	const homeDir = defaultHomeDir();
	// Only the live run refreshes Z.AI; a custom cache directory stays offline.
	if (opts.cachesDir === undefined && homeDir) {
		await refreshZaiUsage({ homeDir, now });
	}
	const cachesDir = opts.cachesDir ?? defaultT3CachesDir();
	const usageDir = opts.cachesDir === undefined && homeDir
		? join(homeDir, AGENT_USAGE_RELATIVE)
		: undefined;
	const snapshots = await readProviderUsageSnapshots(
		cachesDir,
		loaded.config.thresholds.staleMinutes,
		now,
		usageDir,
	);

	return { ...loaded, snapshots, now };
}

async function runStatus(opts: SharedModelOptions) {
	const { config, configPath, localOverridePath, snapshots, now } =
		await loadState(opts);
	const excluded = opts.excludeProvider ?? [];
	const resolutions = resolveAllTiers(config, snapshots, excluded);

	if (opts.json) {
		console.log(
			JSON.stringify(
				{
					configPath,
					localOverridePath,
					thresholds: config.thresholds,
					providers: Object.fromEntries(snapshots),
					picks: Object.fromEntries(
						resolutions.map((resolution) => [resolution.tier, resolution]),
					),
				},
				null,
				2,
			),
		);
		return;
	}

	printHeader("Model usage and routing");
	printInfo(`Config: ${configPath}`);
	if (localOverridePath) {
		printInfo(`Local override: ${localOverridePath}`);
	}
	console.log("");
	console.log(renderStatusReport(config, snapshots, resolutions, now));
}

export const modelsCommand = new Command()
	.description(
		"Inspect live provider usage and resolve usage-aware model picks",
	)
	.option("--json", "Output machine-readable JSON")
	.option(
		"--caches-dir <dir:string>",
		"Override T3 Code provider caches directory",
	)
	.option(
		"--exclude-provider <provider:string>",
		"Temporarily exclude a provider instance (repeatable)",
		{ collect: true },
	)
	.action(async (opts: SharedModelOptions) => {
		await runStatus(opts);
	})
	.command(
		"status",
		new Command()
			.description(
				"Show live provider usage and the current winning model per tier",
			)
			.option("--json", "Output machine-readable JSON")
			.option(
				"--caches-dir <dir:string>",
				"Override T3 Code provider caches directory",
			)
			.option(
				"--exclude-provider <provider:string>",
				"Temporarily exclude a provider instance (repeatable)",
				{ collect: true },
			)
			.action(async (opts: SharedModelOptions) => {
				await runStatus(opts);
			}),
	)
	.command(
		"refresh",
		new Command()
			.description("Refresh the Z.AI coding-plan quota cache")
			.option("--json", "Output machine-readable JSON")
			.action(async (opts: { json?: boolean }) => {
				const homeDir = defaultHomeDir();
				if (!homeDir) {
					printError("HOME is not set; cannot locate the Z.AI cache.");
					Deno.exit(1);
				}

				const result = await refreshZaiUsage({ homeDir, force: true });
				if (opts.json) {
					console.log(JSON.stringify(result, null, 2));
					if (
						result.status === "failed" || result.status === "no-credential"
					) {
						Deno.exit(1);
					}
					return;
				}

				printHeader("Z.AI coding plan usage");
				switch (result.status) {
					case "written": {
						printInfo(`Plan: ${result.planLevel ?? "unknown"}`);
						for (const window of result.windows) {
							const countdown = formatResetCountdown(window.resetsAt ?? null);
							const resetNote = countdown ? ` (${countdown})` : "";
							console.log(
								`  ${window.label}: ${formatPercent(window.usedPercent)}${resetNote}`,
							);
						}
						break;
					}
					case "fresh":
						printInfo(`Cache is fresh: ${result.cachePath}`);
						break;
					case "no-credential":
						printWarning("No Z.AI coding-plan key found in OpenCode auth.");
						Deno.exit(1);
						break;
					case "failed":
						printError(result.message);
						Deno.exit(1);
				}
			}),
	)
	.command(
		"pick",
		new Command()
			.description("Pick the best available model for a single routing tier")
			.arguments("<tier:string>")
			.option("--json", "Output machine-readable JSON")
			.option(
				"--caches-dir <dir:string>",
				"Override T3 Code provider caches directory",
			)
			.option(
				"--exclude-provider <provider:string>",
				"Temporarily exclude a provider instance (repeatable)",
				{ collect: true },
			)
			.action(async (opts: SharedModelOptions, tier: string) => {
				const { config, snapshots } = await loadState(opts);
				let resolution: ReturnType<typeof pickModelForTier>;
				try {
					resolution = pickModelForTier(
						tier,
						config,
						snapshots,
						opts.excludeProvider ?? [],
					);
				} catch (error) {
					printError(error instanceof Error ? error.message : String(error));
					Deno.exit(1);
				}

				if (opts.json) {
					console.log(JSON.stringify(resolution, null, 2));
					if (!resolution.selected) Deno.exit(2);
					return;
				}

				printHeader(`Tier: ${resolution.tier}`);
				if (resolution.description) {
					printInfo(resolution.description);
				}
				console.log("");

				if (!resolution.selected) {
					printError("No available candidates in this tier");
				} else {
					const { candidate, health, reason } = resolution.selected;
					const optsText = formatCandidateOptions(candidate.options);
					console.log(
						`Selected: ${candidate.provider} / ${candidate.model} (${optsText})`,
					);
					console.log(`Health:   ${health} — ${reason}`);
					if (resolution.usedLowFallback) {
						printWarning(
							"All healthy candidates are low or exhausted; using highest-priority low candidate.",
						);
					}
				}

				console.log("");
				console.log("Chain:");
				for (const [idx, entry] of resolution.evaluations.entries()) {
					const marker = resolution.selected?.candidate === entry.candidate
						? "→"
						: " ";
					const optsText = formatCandidateOptions(entry.candidate.options);
					console.log(
						`  ${marker} ${idx + 1}. ${entry.candidate.provider} / ${entry.candidate.model} (${optsText}) [${entry.health}: ${entry.reason}]`,
					);
				}

				if (!resolution.selected) {
					Deno.exit(2);
				}
			}),
	)
	.command(
		"council",
		new Command()
			.description("Show the tri-provider review council with live usage")
			.option("--json", "Output machine-readable JSON")
			.option(
				"--caches-dir <dir:string>",
				"Override T3 Code provider caches directory",
			)
			.option(
				"--exclude-provider <provider:string>",
				"Temporarily exclude a provider instance (repeatable)",
				{ collect: true },
			)
			.action(async (opts: SharedModelOptions) => {
				const { config, snapshots } = await loadState(opts);
				const council = resolveCouncil(
					config,
					snapshots,
					opts.excludeProvider ?? [],
				);

				if (opts.json) {
					console.log(JSON.stringify(council, null, 2));
					return;
				}

				printHeader("Review council");
				if (council.description) {
					printInfo(council.description);
				}
				console.log("");
				for (const member of council.members) {
					const optsText = formatCandidateOptions(member.candidate.options);
					console.log(
						`  ${member.candidate.provider.padEnd(13)} ${member.candidate.model} (${optsText}) — ${member.health}: ${member.reason}`,
					);
				}
			}),
	)
	.command(
		"tiers",
		new Command()
			.description("List all configured routing tiers and fallback chains")
			.option("--json", "Output machine-readable JSON")
			.action(async (opts: { json?: boolean }) => {
				const dotfilesDir = await resolveDotfilesDir();
				const { config } = await readModelsConfig(dotfilesDir);

				if (opts.json) {
					console.log(
						JSON.stringify(
							{
								thresholds: config.thresholds,
								bans: config.bans,
								tiers: config.tiers,
							},
							null,
							2,
						),
					);
					return;
				}

				printHeader("Model routing tiers");
				for (const tier of Object.values(config.tiers)) {
					console.log(`\n${tier.name} — ${tier.description}`);
					for (const [idx, candidate] of tier.candidates.entries()) {
						const optsText = formatCandidateOptions(candidate.options);
						const note = candidate.note ? ` — ${candidate.note}` : "";
						console.log(
							`  ${idx + 1}. ${candidate.provider} / ${candidate.model} (${optsText})${note}`,
						);
					}
				}
			}),
	);
