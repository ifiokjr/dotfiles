/**
 * `dotfiles completion` — Generate shell completion providers.
 */

import { Command } from "@cliffy/command";

const commands = [
	"setup",
	"rebuild",
	"reload",
	"doctor",
	"groups",
	"machine",
	"nix",
	"env",
	"pnpm",
	"uninstall",
	"reset",
	"self",
	"version",
	"help",
	"completion",
];

const optionsByCommand: Record<string, string[]> = {
	completion: ["--help"],
	doctor: ["--help", "--verify"],
	rebuild: [
		"--help",
		"--groups",
		"--skip-check",
		"--update",
		"--brew",
		"--lite",
		"--no-lite",
		"--desktop",
		"--no-desktop",
		"--latest",
		"--force",
		"--rebuild-os",
		"--always-on",
		"--no-always-on",
		"--add-preset",
		"--remove-preset",
		"--dry-run",
	],
	reload: ["--help", "--force", "--no-hooks", "--dry-run"],
	self: ["--help"],
	setup: ["--help"],
};

const subcommandsByCommand: Record<string, string[]> = {
	completion: ["bash", "nushell"],
	env: ["doctor", "secrets", "template"],
	groups: ["list", "info", "deploy", "undeploy"],
	machine: [
		"config",
		"set-lite",
		"set-desktop",
		"set-always-on",
		"add-preset",
		"remove-preset",
		"regenerate",
	],
	nix: ["doctor", "flake", "machine"],
	pnpm: ["sync", "update", "list", "status"],
	self: ["install"],
};

export const completionCommand = new Command()
	.description("Generate shell completion providers")
	.arguments("<shell:string>")
	.action((_opts, shell: string) => {
		switch (shell) {
			case "bash":
				console.log(bashCompletion());
				break;
			case "nu":
			case "nushell":
				console.log(nushellCompletion());
				break;
			default:
				console.error("Supported shells: bash, nushell");
				Deno.exit(1);
		}
	});

function bashCompletion(): string {
	const commandCases = Object.entries(optionsByCommand).map((
		[command, options],
	) =>
		`    ${command}) COMPREPLY=( $(compgen -W "${
			options.join(" ")
		}" -- "$cur") ) ; return 0 ;;`
	).join("\n");
	const subcommandCases = Object.entries(subcommandsByCommand).map((
		[command, subcommands],
	) =>
		`    ${command})
      if [[ COMP_CWORD -eq 2 && "$cur" != --* ]]; then
        COMPREPLY=( $(compgen -W "${subcommands.join(" ")} ${
			(optionsByCommand[command] ?? ["--help"]).join(" ")
		}" -- "$cur") )
        return 0
      fi
      ;;`
	).join("\n");

	return `# bash completion for dotfiles / dot
# Install with:
#   mkdir -p ~/.local/share/bash-completion/completions
#   dot completion bash > ~/.local/share/bash-completion/completions/dot
#   dot completion bash > ~/.local/share/bash-completion/completions/dotfiles

_dotfiles_completion() {
  local cur command
  COMPREPLY=()
  cur="${"$"}{COMP_WORDS[COMP_CWORD]}"
  command="${"$"}{COMP_WORDS[1]}"

  if [[ COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "${
		commands.join(" ")
	} --help --version" -- "$cur") )
    return 0
  fi

  case "$command" in
${subcommandCases}
  esac

  case "$command" in
${commandCases}
  esac
}

complete -F _dotfiles_completion dot
complete -F _dotfiles_completion dotfiles
`;
}

function nushellCompletion(): string {
	return `# Nushell completions for dotfiles / dot
# Install with:
#   mkdir ~/.config/nushell/completions
#   dot completion nushell | save -f ~/.config/nushell/completions/dot-completions.nu
#   use ~/.config/nushell/completions/dot-completions.nu *

export def "nu-complete dot commands" [] {
  ${nuList(commands)}
}

export def "nu-complete dot completion shells" [] {
  [bash nushell]
}

export extern "dot" [
  command?: string@"nu-complete dot commands"
  ...args: string
]

export extern "dotfiles" [
  command?: string@"nu-complete dot commands"
  ...args: string
]

export extern "dot completion" [
  shell?: string@"nu-complete dot completion shells"
]

export extern "dot rebuild" [
  --groups: string
  --skip-check
  --update
  --brew
  --lite
  --no-lite
  --desktop
  --no-desktop
  --latest
  --force
  --rebuild-os
  --always-on
  --no-always-on
  --add-preset: string
  --remove-preset: string
  --dry-run
]

export extern "dot reload" [
  --force
  --no-hooks
  --dry-run
]

export extern "dot doctor" [
  --verify
]

export extern "dot self install" [
  --bin-dir: string
]
`;
}

function nuList(values: string[]): string {
	return `[${values.join(" ")}]`;
}
