/**
 * Resolve paths and configuration for the dotfiles CLI.
 *
 * The dotfiles repo is found by walking up from cwd or falling back to
 * ~/Developer/.dotfiles. This mirrors the logic in the bash setup script.
 */

import { dirname, join } from "@std/path";
import { exists } from "@std/fs";

/** Well-known default location for the dotfiles repo. */
export const DEFAULT_DOTFILES_DIR = join(
  Deno.env.get("HOME") ?? "~",
  "Developer/.dotfiles",
);

/** Detect the current platform. */
export type Platform = "macos" | "linux" | "windows" | "bsd";

export function detectPlatform(): Platform {
  switch (Deno.build.os) {
    case "darwin":
      return "macos";
    case "linux":
      return "linux";
    case "windows":
      return "windows";
    default:
      return "bsd";
  }
}

/** Detect CPU architecture in Nix format. */
export function detectArch(): string {
  switch (Deno.build.arch) {
    case "aarch64":
      return "aarch64";
    case "x86_64":
      return "x86_64";
    default:
      return Deno.build.arch;
  }
}

/** Get the Nix system triple (e.g. "aarch64-darwin"). */
export function nixSystem(): string {
  return `${detectArch()}-${detectPlatform()}`;
}

/** Resolve the dotfiles repository directory. */
export async function resolveDotfilesDir(): Promise<string> {
  // 1. DOTFILES_DIR env var (highest priority)
  const envDir = Deno.env.get("DOTFILES_DIR");
  if (envDir && await exists(envDir, { isDirectory: true })) {
    return envDir;
  }

  // 2. Walk up from cwd looking for a marker
  let dir = Deno.cwd();
  for (let i = 0; i < 20; i++) {
    if (
      await exists(join(dir, "Configs"), { isDirectory: true }) &&
      await exists(join(dir, "setup"), { isFile: true })
    ) {
      return dir;
    }
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }

  // 3. Default location
  if (await exists(DEFAULT_DOTFILES_DIR, { isDirectory: true })) {
    return DEFAULT_DOTFILES_DIR;
  }

  throw new Error(
    "Cannot find dotfiles repository. Set DOTFILES_DIR or run from within the repo.",
  );
}

/** Resolve the nix config directory (follows symlinks). */
export async function resolveNixConfigDir(dotfilesDir: string): Promise<string> {
  const home = Deno.env.get("HOME") ?? "~";
  const linkPath = join(home, ".config/nix");

  // If it's a symlink, resolve it
  try {
    const stat = await Deno.lstat(linkPath);
    if (stat.isSymlink) {
      return await Deno.realPath(linkPath);
    }
  } catch {
    // Doesn't exist — fall through
  }

  // Check if flake.nix exists and is a symlink to the repo
  const flakeNix = join(linkPath, "flake.nix");
  try {
    const flakeStat = await Deno.lstat(flakeNix);
    if (flakeStat.isSymlink) {
      const resolved = await Deno.realPath(flakeNix);
      return dirname(resolved);
    }
  } catch {
    // fall through
  }

  // Check if the directory exists and has flake.nix
  if (await exists(join(linkPath, "flake.nix"), { isFile: true })) {
    return linkPath;
  }

  // Fall back to the repo path (CI / non-deployed scenario)
  return join(dotfilesDir, "Configs/nix/.config/nix");
}

/** Resolve the machine.nix path. */
export function machineConfigPath(nixConfigDir: string): string {
  return join(nixConfigDir, "machine.nix");
}

/** Known setup presets. */
export interface Preset {
  name: string;
  description: string;
  defaultLite: boolean;
}

export const PRESETS: Record<string, Preset> = {
  core: {
    name: "core",
    description: "Safe default: core shell, editor, and foundational CLI tooling.",
    defaultLite: true,
  },
  dev: {
    name: "dev",
    description: "Core setup plus developer-focused tools and managed CLIs.",
    defaultLite: true,
  },
  workstation: {
    name: "workstation",
    description: "Full personal-machine setup, including GUI-heavy applications.",
    defaultLite: false,
  },
  ci: {
    name: "ci",
    description: "Minimal non-interactive setup intended for CI and containers.",
    defaultLite: true,
  },
};

/** Known machine presets (stored in machine.nix, not setup presets). */
export const MACHINE_PRESETS: Record<string, string> = {
  ironclaw: "Ironclaw agent runtime — enables libSQL database and ironclaw service",
};

/** Discover all configuration groups by scanning Configs/ directory. */
export async function discoverGroups(dotfilesDir: string): Promise<string[]> {
  const configsDir = join(dotfilesDir, "Configs");
  const groups: string[] = [];

  try {
    for await (const entry of Deno.readDir(configsDir)) {
      if (entry.isDirectory) {
        groups.push(entry.name);
      }
    }
  } catch {
    // Configs/ doesn't exist
  }

  return groups.sort();
}

/** Load a group's TOML metadata. */
export async function loadGroupMetadata(
  dotfilesDir: string,
  groupName: string,
): Promise<GroupMetadata> {
  const metadataPath = join(dotfilesDir, `Configs/${groupName}.group.toml`);

  if (!await exists(metadataPath)) {
    return {
      description: groupName,
      presets: [],
      dependsOn: [],
      phase: "normal",
      platforms: [],
    };
  }

  const content = await Deno.readTextFile(metadataPath);
  const parsed = parseSimpleToml(content);

  return {
    description: String(parsed.description ?? groupName),
    presets: parseStringArray(parsed.presets),
    dependsOn: parseStringArray(parsed.depends_on),
    phase: validatePhase(parsed.phase),
    platforms: parseStringArray(parsed.platforms),
  };
}

export interface GroupMetadata {
  description: string;
  presets: string[];
  dependsOn: string[];
  phase: "early" | "bootstrap" | "normal" | "late";
  platforms: string[];
}

/** Phase validation — defaults to "normal". */
function validatePhase(value: unknown): GroupMetadata["phase"] {
  const valid = ["early", "bootstrap", "normal", "late"];
  if (typeof value === "string" && valid.includes(value)) {
    return value as GroupMetadata["phase"];
  }
  return "normal";
}

/** Minimal TOML parser — handles flat key=value and simple arrays. */
function parseSimpleToml(content: string): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const line of content.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    const eqIndex = trimmed.indexOf("=");
    if (eqIndex === -1) continue;

    const key = trimmed.slice(0, eqIndex).trim();
    let value: unknown = trimmed.slice(eqIndex + 1).trim();

    if (typeof value === "string") {
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.slice(1, -1);
      } else if (value.startsWith("[") && value.endsWith("]")) {
        // Parse simple arrays like ["a", "b"]
        value = value.slice(1, -1)
          .split(",")
          .map((s: string) => s.trim().replace(/^"|"$/g, ""))
          .filter((s: string) => s.length > 0);
      }
    }

    result[key] = value;
  }
  return result;
}

function parseStringArray(value: unknown): string[] {
  if (Array.isArray(value)) return value as string[];
  if (typeof value === "string") {
    return value.split(/\s+/).filter((s) => s.length > 0);
  }
  return [];
}

/** Find an executable on PATH. */
export async function findExecutable(name: string): Promise<string | null> {
  try {
    const cmd = new Deno.Command("which", { args: [name] });
    const { stdout } = await cmd.output();
    const path = new TextDecoder().decode(stdout).trim();
    return path.length > 0 ? path : null;
  } catch {
    return null;
  }
}

/** Check if a command is available on PATH. */
export async function commandExists(name: string): Promise<boolean> {
  try {
    const cmd = new Deno.Command(name, {
      args: ["--version"],
      stderr: "null",
      stdout: "null",
    });
    const status = await cmd.output();
    return status.success;
  } catch {
    return false;
  }
}

/** Run a shell command and stream output to stdout/stderr. */
export async function runCommand(
  cmd: string[],
  options?: { cwd?: string; env?: Record<string, string> },
): Promise<{ code: number; success: boolean }> {
  const [command, ...args] = cmd;
  const p = new Deno.Command(command, {
    args,
    cwd: options?.cwd,
    env: options?.env
      ? { ...Deno.env.toObject(), ...options.env }
      : undefined,
    stdout: "inherit",
    stderr: "inherit",
  });

  const status = await p.output();
  return { code: status.code, success: status.success };
}

/** Format a command for display (for dry-run output). */
export function formatCommand(cmd: string[]): string {
  return cmd.map((part) =>
    part.includes(" ") || part.includes('"') ? `"${part}"` : part
  ).join(" ");
}

/** Colored output helpers. */
export const colors = {
  red: (s: string) => `\x1b[0;31m${s}\x1b[0m`,
  green: (s: string) => `\x1b[0;32m${s}\x1b[0m`,
  yellow: (s: string) => `\x1b[1;33m${s}\x1b[0m`,
  blue: (s: string) => `\x1b[0;34m${s}\x1b[0m`,
  cyan: (s: string) => `\x1b[0;36m${s}\x1b[0m`,
  bold: (s: string) => `\x1b[1m${s}\x1b[0m`,
};

/** Print helpers matching the bash setup script's output style. */
export function printHeader(msg: string) {
  console.log(`\n${colors.bold(colors.cyan("==>"))} ${colors.bold(msg)}`);
}

export function printSuccess(msg: string) {
  console.log(`${colors.green("✓")} ${msg}`);
}

export function printError(msg: string) {
  console.error(`${colors.red("✗")} ${msg}`);
}

export function printWarning(msg: string) {
  console.log(`${colors.yellow("⚠")} ${msg}`);
}

export function printInfo(msg: string) {
  console.log(`${colors.blue("→")} ${msg}`);
}