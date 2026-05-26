/**
 * `dotfiles version` — Print CLI version and repo info
 */

import { Command } from "@cliffy/command";
import { VERSION } from "../main.ts";
import {
  detectArch,
  detectPlatform,
  resolveDotfilesDir,
} from "../lib/config.ts";

export const versionCommand = new Command()
  .description("Print CLI version and environment info")
  .option("--verbose", "Show additional environment details")
  .action(async (opts) => {
    console.log(`dotfiles v${VERSION}`);
    console.log(`Platform: ${detectPlatform()}-${detectArch()}`);

    if (opts.verbose) {
      try {
        const dotfilesDir = await resolveDotfilesDir();
        console.log(`Repo:     ${dotfilesDir}`);

        // Try to get git info
        try {
          const { stdout } = await new Deno.Command("git", {
            args: ["describe", "--tags", "--always", "--dirty"],
            cwd: dotfilesDir,
            stdout: "piped",
            stderr: "null",
          }).output();
          console.log(`Git:      ${new TextDecoder().decode(stdout).trim()}`);
        } catch {
          console.log("Git:      (not a git repo or git not available)");
        }

        // Try to check nix version
        try {
          const { stdout } = await new Deno.Command("nix", {
            args: ["--version"],
            stdout: "piped",
            stderr: "null",
          }).output();
          const nixVersion = new TextDecoder().decode(stdout).split("\n")[0]
            .trim();
          console.log(`Nix:      ${nixVersion}`);
        } catch {
          console.log("Nix:      (not installed)");
        }
      } catch (e) {
        console.log(`Repo:     (error: ${(e as Error).message})`);
      }
    }
  });
