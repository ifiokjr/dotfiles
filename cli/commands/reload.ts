/**
 * `dotfiles reload` — Tuckr reload all groups (non-destructive)
 *
 * Phase 1: Shells out to the nushell tuckr:reload script.
 * Phase 2: Will be reimplemented natively to call tuckr directly.
 */

import { Command } from "@cliffy/command";
import {
  resolveDotfilesDir,
  runCommand,
  findExecutable,
  printHeader,
  printError,
} from "../lib/config.ts";

export const reloadCommand = new Command()
  .description("Reload tuckr configuration groups (non-destructive, re-applies symlinks)")
  .option("--group <group:string>", "Reload a single group instead of all groups")
  .action(async (opts) => {
    const dotfilesDir = await resolveDotfilesDir();

    const reloadScript = await findExecutable("tuckr:reload");
    const fallbackScript = `${dotfilesDir}/Configs/scripts/.local/bin/tuckr:reload`;

    const script = reloadScript ?? fallbackScript;
    const args: string[] = [];

    if (opts.group) args.push("--group", opts.group);

    printHeader("Reloading dotfiles configuration");
    const { code, success } = await runCommand([script, ...args], {
      cwd: dotfilesDir,
    });

    if (!success) {
      printError(`Reload failed with exit code ${code}`);
      Deno.exit(code);
    }
  });