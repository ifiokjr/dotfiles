#!/usr/bin/env bash

setup_state_dir() {
	printf '%s\n' "$HOME/.local/state/dotfiles"
}

setup_phase_file() {
	printf '%s/setup-phase\n' "$(setup_state_dir)"
}

write_setup_phase() {
	local phase="$1"
	mkdir -p "$(setup_state_dir)"
	printf '%s\n' "$phase" >"$(setup_phase_file)"
	# shellcheck disable=SC2034
	SETUP_CURRENT_PHASE="$phase"
}

read_setup_phase() {
	if [ -f "$(setup_phase_file)" ]; then
		cat "$(setup_phase_file)"
	fi
}

clear_setup_phase() {
	rm -f "$(setup_phase_file)"
}

phase_rank() {
	case "$1" in
	install-nix)
		printf '10\n'
		;;
	install-tuckr)
		printf '20\n'
		;;
	install-nushell)
		printf '30\n'
		;;
	setup-tuckr-symlink)
		printf '40\n'
		;;
	deploy | deploy:*)
		printf '50\n'
		;;
	*)
		printf '0\n'
		;;
	esac
}

from_target_is_valid() {
	case "$1" in
	install-nix | install-tuckr | install-nushell | setup-tuckr-symlink | deploy | deploy:*)
		return 0
		;;
	esac

	group_exists "$1"
}

resume_target_group() {
	case "$1" in
	deploy:*)
		printf '%s\n' "${1#deploy:}"
		;;
	deploy)
		printf '\n'
		;;
	*)
		printf '\n'
		;;
	esac
}

should_run_phase() {
	local phase="$1"
	local target="${FROM_TARGET:-}"
	local target_rank
	local phase_rank_value

	if [ -z "$target" ]; then
		return 0
	fi

	if group_exists "$target"; then
		target="deploy:$target"
	fi

	target_rank="$(phase_rank "$target")"
	phase_rank_value="$(phase_rank "$phase")"
	[ "$phase_rank_value" -ge "$target_rank" ]
}

apply_resume_request() {
	local saved_phase

	if [ "$RESUME" = false ]; then
		return 0
	fi

	saved_phase="$(read_setup_phase)"
	if [ -z "$saved_phase" ]; then
		print_error "No saved setup phase found for --resume"
		return 1
	fi

	case "$saved_phase" in
	deploy:*)
		FROM_TARGET="${saved_phase#deploy:}"
		print_info "Resuming deployment from group: $FROM_TARGET"
		;;
	*)
		FROM_TARGET="$saved_phase"
		print_info "Resuming from phase: $FROM_TARGET"
		;;
	esac
}

print_resume_guidance() {
	local failed_phase="${1:-$(read_setup_phase)}"

	if [ -z "$failed_phase" ]; then
		return 0
	fi

	print_error "Setup failed during: $failed_phase"
	print_info "Retry the last failed step with: ./setup --resume"
	case "$failed_phase" in
	deploy:*)
		print_info "Retry just that group with: ./setup --from ${failed_phase#deploy:}"
		;;
	esac
}

handle_setup_exit() {
	local status="$?"

	if [ "$SETUP_TRACK_STATE" != true ]; then
		return 0
	fi

	if [ "$status" -ne 0 ]; then
		print_resume_guidance
	else
		clear_setup_phase
	fi
}
