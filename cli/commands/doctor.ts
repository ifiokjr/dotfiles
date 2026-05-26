/**
 * `dotfiles doctor` — Preflight / health checks
 *
 * Phase 1: Shells out to `./setup --doctor`.
 */

import { Command } from "@cliffy/command";
import {
  resolveDotfilesDir,
  runCommand,
  printError,
} from "../lib/config.ts";

export const doctorCommand = new Command()
  .description("Run preflight checks without changing the machine")
  .action(async () => {
    const dotfilesDir = await resolveDotfilesDir();
    const setupScript = `${dotfilesDir}/setup`;

    const { code, success } = await runCommand([setupScript, "--doctor"], {
      cwd: dotfilesDir,
    });

    if (!success) {
      printError(`Doctor found issues (exit code ${code})`);
      Deno.exit(code);
    }
  });