/**
 * dotfiles — Unified CLI for managing dotfiles
 *
 * Setup, rebuild, reload, doctor, and more — all from one command.
 */

import { Command } from "@cliffy/command";
import { setupCommand } from "./commands/setup.ts";
import { rebuildCommand } from "./commands/rebuild.ts";
import { reloadCommand } from "./commands/reload.ts";
import { doctorCommand } from "./commands/doctor.ts";
import { groupsCommand } from "./commands/groups.ts";
import { machineCommand } from "./commands/machine.ts";
import { nixCommand } from "./commands/nix.ts";
import { envCommand } from "./commands/env.ts";
import { pnpmCommand } from "./commands/pnpm.ts";
import { uninstallCommand } from "./commands/uninstall.ts";
import { resetCommand } from "./commands/reset.ts";
import { versionCommand } from "./commands/version.ts";

export const VERSION = "0.1.0";

await new Command()
  .name("dotfiles")
  .version(VERSION)
  .description(
    "Manage your dotfiles — setup, rebuild, reload, and more.\n\n" +
      "Run 'dotfiles help <command>' for detailed usage of any subcommand.",
  )
  .command("setup", setupCommand)
  .command("rebuild", rebuildCommand)
  .command("reload", reloadCommand)
  .command("doctor", doctorCommand)
  .command("groups", groupsCommand)
  .command("machine", machineCommand)
  .command("nix", nixCommand)
  .command("env", envCommand)
  .command("pnpm", pnpmCommand)
  .command("uninstall", uninstallCommand)
  .command("reset", resetCommand)
  .command("version", versionCommand)
  .parse(Deno.args);