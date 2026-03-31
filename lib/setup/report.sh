#!/usr/bin/env bash

json_escape() {
	local value="${1:-}"
	value=${value//\\/\\\\}
	value=${value//"/\\"/}
	value=${value//$'\n'/\\n}
	value=${value//$'\r'/\\r}
	value=${value//$'\t'/\\t}
	printf '%s' "$value"
}

json_array_from_words() {
	local array_name="$1"
	local values=()
	local item
	local result=""

	eval "values=(\"\${${array_name}[@]-}\")"
	for item in "${values[@]}"; do
		result="${result}${result:+, }\"$(json_escape "$item")\""
	done

	printf '[%s]' "$result"
}

command_version_or_unknown() {
	local command_name="$1"
	if command_exists "$command_name"; then
		"$command_name" --version 2>/dev/null | head -n 1 || printf 'unknown\n'
	else
		printf 'unavailable\n'
	fi
}

write_setup_report() {
	local report_dir="$HOME/.local/state/dotfiles"
	local report_path="$report_dir/setup-report.json"
	local timestamp
	local revision="unknown"
	local duration_seconds="0"
	local hooks_json
	local groups_json
	local warnings_json
	local nix_version
	local nu_version
	local tuckr_version

	mkdir -p "$report_dir"

	timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	if [ -d "$DOTFILES_DIR/.git" ]; then
		revision="$(git -C "$DOTFILES_DIR" rev-parse HEAD 2>/dev/null || printf 'unknown')"
	fi
	if [ -n "${SETUP_STARTED_AT:-}" ]; then
		duration_seconds="$(($(date +%s) - SETUP_STARTED_AT))"
	fi

	collect_plan_hook_groups
	groups_json="$(json_array_from_words ORDERED_GROUPS)"
	hooks_json="$(json_array_from_words PLAN_HOOK_GROUPS)"
	warnings_json="$(json_array_from_words REPORT_WARNING_MESSAGES)"
	nix_version="$(command_version_or_unknown nix)"
	nu_version="$(command_version_or_unknown nu)"
	tuckr_version="$(command_version_or_unknown tuckr)"

	cat >"$report_path" <<EOF
{
  "timestamp": "$(json_escape "$timestamp")",
  "platform": "$(json_escape "$PLATFORM")",
  "git_revision": "$(json_escape "$revision")",
  "preset": "$(json_escape "${PRESET:-}")",
  "clone_location": "$(json_escape "$DOTFILES_DIR")",
  "flags": {
    "skip_nix": $SKIP_NIX,
    "lite": $LITE,
    "no_confirm": $NO_CONFIRM
  },
  "groups": $groups_json,
  "hooks": $hooks_json,
  "warnings": $warnings_json,
  "versions": {
    "nix": "$(json_escape "$nix_version")",
    "nu": "$(json_escape "$nu_version")",
    "tuckr": "$(json_escape "$tuckr_version")"
  },
  "duration_seconds": $duration_seconds
}
EOF

	print_success "Wrote setup report: $report_path"
}
