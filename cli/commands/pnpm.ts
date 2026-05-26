/**
 * `dotfiles pnpm` — pnpm global package management
 */

import { Command } from "@cliffy/command";
import { printError, resolveDotfilesDir, runCommand } from "../lib/config.ts";

function pnpmScript(name: string, dotfilesDir: string): string {
  return `${dotfilesDir}/Configs/scripts/.local/bin/pnpm:global:${name}`;
}

export const pnpmCommand = new Command()
  .description("Manage pnpm global packages managed by dotfiles")
  .command(
    "list",
    new Command()
      .description("List managed pnpm global packages")
      .action(async () => {
        const dotfilesDir = await resolveDotfilesDir();
        const { code, success } = await runCommand(
          [pnpmScript("list", dotfilesDir)],
          { cwd: dotfilesDir },
        );
        if (!success) Deno.exit(code);
      }),
  )
  .command(
    "sync",
    new Command()
      .description("Sync pnpm global packages with manifest")
      .action(async () => {
        const dotfilesDir = await resolveDotfilesDir();
        const { code, success } = await runCommand(
          [pnpmScript("sync", dotfilesDir)],
          { cwd: dotfilesDir },
        );
        if (!success) {
          printError(`pnpm global sync failed (exit code ${code})`);
          Deno.exit(code);
        }
      }),
  )
  .command(
    "add",
    new Command()
      .description("Add a package to the pnpm global manifest and install it")
      .arguments("<packages...:string>")
      .action(async (_opts, ...packages: string[]) => {
        const dotfilesDir = await resolveDotfilesDir();
        const { code, success } = await runCommand(
          [pnpmScript("add", dotfilesDir), ...packages],
          { cwd: dotfilesDir },
        );
        if (!success) Deno.exit(code);
      }),
  )
  .command(
    "remove",
    new Command()
      .description("Remove a package from the pnpm global manifest")
      .arguments("<packages...:string>")
      .action(async (_opts, ...packages: string[]) => {
        const dotfilesDir = await resolveDotfilesDir();
        const { code, success } = await runCommand(
          [pnpmScript("remove", dotfilesDir), ...packages],
          { cwd: dotfilesDir },
        );
        if (!success) Deno.exit(code);
      }),
  )
  .command(
    "update",
    new Command()
      .description("Update pnpm global packages (or specific ones)")
      .arguments("[packages...:string]")
      .action(async (_opts, ...packages: string[]) => {
        const dotfilesDir = await resolveDotfilesDir();
        const { code, success } = await runCommand(
          [pnpmScript("update", dotfilesDir), ...packages],
          { cwd: dotfilesDir },
        );
        if (!success) Deno.exit(code);
      }),
  );
