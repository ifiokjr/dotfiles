#!/usr/bin/env bash

plan_repo_action() {
	if [ "${STARTED_IN_REPO:-false}" = true ]; then
		printf 'Reuse repository: %s\n' "$DOTFILES_DIR"
		return 0
	fi

	if [ -d "$DOTFILES_DIR/.git" ]; then
		printf 'Reuse existing clone at: %s\n' "$DOTFILES_DIR"
	else
		printf 'Clone repository to: %s\n' "$DOTFILES_DIR"
	fi
}

plan_nix_action() {
	if [ "$SKIP_NIX" = true ]; then
		printf 'Skip Nix installation (--skip-nix)\n'
	elif command_exists nix && nix --version >/dev/null 2>&1; then
		printf 'Reuse existing Nix installation\n'
	else
		printf 'Install Determinate Nix\n'
	fi
}

plan_bootstrap_tools() {
	local tools=()

	if [ "${STARTED_IN_REPO:-false}" = false ] && ! can_run_git; then
		tools+=("git")
	fi
	if ! command_exists tuckr; then
		tools+=("tuckr")
	fi
	if ! command_exists nu; then
		tools+=("nushell")
	fi

	if [ ${#tools[@]} -eq 0 ]; then
		printf 'none\n'
		return 0
	fi

	printf '%s\n' "$(join_array_by tools ', ')"
}

plan_gui_mode() {
	if [ "$LITE" = true ]; then
		printf 'CLI-focused / GUI-heavy applications skipped\n'
	else
		printf 'GUI-heavy applications may be installed\n'
	fi
}

plan_expected_duration() {
	if [ -n "$PRESET" ]; then
		case "$PRESET" in
		workstation)
			printf '20–40 minutes\n'
			return 0
			;;
		ci)
			printf '5–10 minutes\n'
			return 0
			;;
		esac
	fi

	if [ "$LITE" = true ]; then
		printf '5–20 minutes\n'
	else
		printf '10–30 minutes\n'
	fi
}

collect_plan_hook_groups() {
	PLAN_HOOK_GROUPS=()
	local group

	if [ "${ORDERED_GROUPS+set}" != "set" ]; then
		return 0
	fi

	for group in "${ORDERED_GROUPS[@]}"; do
		if group_has_repo_hooks "$group"; then
			PLAN_HOOK_GROUPS+=("$group")
		fi
	done
}

print_bootstrap_plan() {
	print_header "Setup plan"
	echo "  • Platform: $PLATFORM"
	if [ -n "$PRESET" ]; then
		echo "  • Preset: $PRESET"
	fi
	if [ -n "$DEPLOY_GROUPS" ]; then
		echo "  • Explicit groups: $DEPLOY_GROUPS"
	fi
	echo "  • $(plan_repo_action)"
	echo "  • Nix: $(plan_nix_action)"
	echo "  • Temporary bootstrap tools: $(plan_bootstrap_tools)"
	echo "  • GUI applications: $(plan_gui_mode)"
	echo "  • Expected duration: $(plan_expected_duration)"
	echo "  • Detailed group and hook plan will be shown once repository metadata is available"
	echo ""
}

print_execution_plan() {
	print_header "Setup plan"
	echo "  • Platform: $PLATFORM"
	if [ -n "$PRESET" ]; then
		echo "  • Preset: $PRESET"
	else
		echo "  • Preset: none"
	fi
	if [ -n "$DEPLOY_GROUPS" ]; then
		echo "  • Explicit groups: $DEPLOY_GROUPS"
	fi
	echo "  • $(plan_repo_action)"
	echo "  • Nix: $(plan_nix_action)"
	echo "  • Temporary bootstrap tools: $(plan_bootstrap_tools)"
	echo "  • GUI applications: $(plan_gui_mode)"
	echo "  • Expected duration: $(plan_expected_duration)"

	if [ "${ORDERED_GROUPS+set}" = "set" ] && [ ${#ORDERED_GROUPS[@]} -gt 0 ]; then
		echo "  • Deploy groups: $(join_array_by ORDERED_GROUPS ', ')"
	else
		echo "  • Deploy groups: none"
	fi

	collect_plan_hook_groups
	if [ ${#PLAN_HOOK_GROUPS[@]} -gt 0 ]; then
		echo "  • Hooks that will run: $(join_array_by PLAN_HOOK_GROUPS ', ')"
	else
		echo "  • Hooks that will run: none"
	fi
	echo ""
}
