#!/usr/bin/env bash

group_metadata_path() {
	printf '%s\n' "$DOTFILES_DIR/Configs/$1.group.toml"
}

group_reset_metadata() {
	GROUP_DESCRIPTION=""
	GROUP_PRESETS=""
	GROUP_DEPENDS_ON=""
	GROUP_PHASE="normal"
	GROUP_PLATFORMS=""
}

phase_is_valid() {
	case "$1" in
	early | bootstrap | normal | late)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

platform_is_valid() {
	case "$1" in
	macos | linux | windows | bsd)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

preset_is_valid() {
	case "$1" in
	core | dev | workstation | ci)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

validate_loaded_group_metadata() {
	local group="$1"
	local metadata_file
	local platform
	local preset

	metadata_file="$(group_metadata_path "$group")"

	if ! phase_is_valid "$GROUP_PHASE"; then
		print_error "Invalid phase '$GROUP_PHASE' in $metadata_file"
		return 1
	fi

	for preset in $GROUP_PRESETS; do
		if ! preset_is_valid "$preset"; then
			print_error "Invalid preset '$preset' in $metadata_file"
			return 1
		fi
	done

	for platform in $GROUP_PLATFORMS; do
		if ! platform_is_valid "$platform"; then
			print_error "Invalid platform '$platform' in $metadata_file"
			return 1
		fi
	done
}

load_group_metadata() {
	local group="$1"
	local metadata_file
	local metadata_lines
	local key
	local value

	group_reset_metadata
	metadata_file="$(group_metadata_path "$group")"
	if [ -f "$metadata_file" ]; then
		if ! command_exists nu; then
			print_error "Nushell is required to read group metadata: $metadata_file"
			return 1
		fi

		# shellcheck disable=SC2016
		if ! metadata_lines="$(GROUP_METADATA_PATH="$metadata_file" nu -c '
			let data = (open --raw $env.GROUP_METADATA_PATH | from toml)
			[
			  ["description", ($data | get --optional description | default "")],
			  ["presets", (($data | get --optional presets | default []) | str join " ")],
			  ["depends_on", (($data | get --optional depends_on | default []) | str join " ")],
			  ["phase", ($data | get --optional phase | default "normal")],
			  ["platforms", (($data | get --optional platforms | default []) | str join " ")]
			]
			| each { |row| $"($row.0)\t($row.1)" }
			| str join (char nl)
		')"; then
			print_error "Invalid group metadata: $metadata_file"
			return 1
		fi

		while IFS=$'\t' read -r key value; do
			case "$key" in
			description)
				GROUP_DESCRIPTION="$value"
				;;
			presets)
				GROUP_PRESETS="$value"
				;;
			depends_on)
				GROUP_DEPENDS_ON="$value"
				;;
			phase)
				GROUP_PHASE="$value"
				;;
			platforms)
				GROUP_PLATFORMS="$value"
				;;
			esac
		done <<<"$metadata_lines"
	fi

	if [ -z "$GROUP_DESCRIPTION" ]; then
		GROUP_DESCRIPTION="$group"
	fi

	validate_loaded_group_metadata "$group"
}

discover_all_groups() {
	ALL_GROUPS=()

	if [ ! -d "$DOTFILES_DIR/Configs" ]; then
		return 0
	fi

	while IFS= read -r -d '' dir; do
		ALL_GROUPS+=("$(basename "$dir")")
	done < <(find "$DOTFILES_DIR/Configs" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
}

group_platform_summary() {
	local group="$1"

	load_group_metadata "$group" || return 1
	if [ -n "$GROUP_PLATFORMS" ]; then
		printf '%s\n' "$GROUP_PLATFORMS"
		return 0
	fi

	case "$group" in
	*_macos)
		printf 'macos\n'
		;;
	*_linux)
		printf 'linux\n'
		;;
	*_windows)
		printf 'windows\n'
		;;
	*_bsd)
		printf 'bsd\n'
		;;
	*)
		printf 'all\n'
		;;
	esac
}

group_hook_summary() {
	local group="$1"
	local hooks=()

	[ -f "$DOTFILES_DIR/Hooks/$group/pre.sh" ] && hooks+=("pre")
	[ -f "$DOTFILES_DIR/Hooks/$group/post.sh" ] && hooks+=("post")
	[ -f "$DOTFILES_DIR/Hooks/$group/rm.sh" ] && hooks+=("rm")

	if [ ${#hooks[@]} -eq 0 ]; then
		printf 'none\n'
	else
		printf '%s\n' "$(join_array_by hooks ', ')"
	fi
}

group_deploy_targets() {
	local group="$1"
	local group_dir="$DOTFILES_DIR/Configs/$group"
	local entry
	local rel
	local root
	local target_name
	local targets=()

	while IFS= read -r -d '' entry; do
		rel="${entry#"${group_dir}"/}"
		case "$rel" in
		.config/*)
			target_name="$(printf '%s' "$rel" | cut -d/ -f2)"
			root="$HOME/.config/$target_name"
			;;
		.local/*)
			target_name="$(printf '%s' "$rel" | cut -d/ -f2)"
			root="$HOME/.local/$target_name"
			;;
		Library/*)
			root="$HOME/$(printf '%s' "$rel" | cut -d/ -f1-2)"
			;;
		*)
			root="$HOME/${rel%%/*}"
			;;
		esac
		append_unique_array_item targets "~${root#"$HOME"}"
	done < <(find "$group_dir" -mindepth 1 \( -type f -o -type l \) ! -name '.tuckrignore' -print0)

	if [ ${#targets[@]} -eq 0 ]; then
		printf 'none\n'
	else
		printf '%s\n' "$(join_array_by targets ', ')"
	fi
}

list_groups() {
	local group

	discover_all_groups
	if [ ${#ALL_GROUPS[@]} -eq 0 ]; then
		print_warning "No configuration groups found in Configs/"
		return 0
	fi

	print_header "Available configuration groups"
	for group in "${ALL_GROUPS[@]}"; do
		load_group_metadata "$group" || return 1
		printf '  %-12s %s\n' "$group" "$GROUP_DESCRIPTION"
	done
}

explain_group() {
	local group="$1"
	local platforms
	local targets
	local hooks
	local presets
	local depends

	if ! group_exists "$group"; then
		print_error "Unknown configuration group: $group"
		return 1
	fi

	load_group_metadata "$group" || return 1
	platforms="$(group_platform_summary "$group")"
	targets="$(group_deploy_targets "$group")"
	hooks="$(group_hook_summary "$group")"
	presets="${GROUP_PRESETS:-none}"
	depends="${GROUP_DEPENDS_ON:-none}"

	print_header "Group: $group"
	printf '  Description: %s\n' "$GROUP_DESCRIPTION"
	printf '  Deploys to:  %s\n' "$targets"
	printf '  Platforms:   %s\n' "$platforms"
	printf '  Hooks:       %s\n' "$hooks"
	printf '  Depends on:  %s\n' "$depends"
	printf '  Presets:     %s\n' "$presets"
	printf '  Phase:       %s\n' "$GROUP_PHASE"
}

group_exists() {
	[ -d "$DOTFILES_DIR/Configs/$1" ]
}

group_supports_platform_for() {
	local group="$1"
	local target_platform="$2"

	if ! load_group_metadata "$group"; then
		return 2
	fi

	if [ -n "$GROUP_PLATFORMS" ]; then
		if list_contains_word "$GROUP_PLATFORMS" "$target_platform"; then
			return 0
		fi

		return 1
	fi

	case "$group" in
	*_macos)
		[ "$target_platform" = "macos" ]
		return $?
		;;
	*_linux)
		[ "$target_platform" = "linux" ]
		return $?
		;;
	*_windows)
		[ "$target_platform" = "windows" ]
		return $?
		;;
	*_bsd)
		[ "$target_platform" = "bsd" ]
		return $?
		;;
	*)
		return 0
		;;
	esac
}

group_supports_platform() {
	# shellcheck disable=SC2153
	group_supports_platform_for "$1" "$PLATFORM"
}

group_has_repo_hooks() {
	local group="$1"

	[ -f "$DOTFILES_DIR/Hooks/$group/pre.sh" ] ||
		[ -f "$DOTFILES_DIR/Hooks/$group/post.sh" ] ||
		[ -f "$DOTFILES_DIR/Hooks/$group/rm.sh" ]
}

group_deploy_mode() {
	if group_has_repo_hooks "$1"; then
		printf 'set\n'
	else
		printf 'add\n'
	fi
}

preset_exists() {
	case "$1" in
	core | dev | workstation | ci)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

preset_default_lite() {
	case "$1" in
	workstation)
		printf 'false\n'
		;;
	core | dev | ci)
		printf 'true\n'
		;;
	*)
		printf 'false\n'
		;;
	esac
}

preset_description() {
	case "$1" in
	core)
		printf '%s\n' 'Safe default: core shell, editor, and foundational CLI tooling.'
		;;
	dev)
		printf '%s\n' 'Core setup plus developer-focused tools and managed CLIs.'
		;;
	workstation)
		printf '%s\n' 'Full personal-machine setup, including GUI-heavy applications.'
		;;
	ci)
		printf '%s\n' 'Minimal non-interactive setup intended for CI and containers.'
		;;
	*)
		return 1
		;;
	esac
}

preset_group_matches() {
	local group="$1"
	local preset="$2"

	if ! load_group_metadata "$group"; then
		return 2
	fi

	list_contains_word "$GROUP_PRESETS" "$preset"
}

expand_selected_group_dependencies_recursive() {
	local group="$1"
	local dependency

	if ! group_exists "$group"; then
		print_error "Unknown dependency '$group' declared in metadata"
		return 1
	fi

	group_supports_platform_for "$group" "$PLATFORM"
	case $? in
	0) ;;
	1)
		print_error "Group '$group' is not enabled for platform: $PLATFORM"
		return 1
		;;
	*)
		return 1
		;;
	esac

	append_unique_array_item SELECTED_GROUPS "$group"

	load_group_metadata "$group" || return 1
	for dependency in $GROUP_DEPENDS_ON; do
		if ! group_exists "$dependency"; then
			print_error "Unknown dependency '$dependency' in $(group_metadata_path "$group")"
			return 1
		fi

		group_supports_platform_for "$dependency" "$PLATFORM"
		case $? in
		0) ;;
		1)
			print_error "Group '$group' depends on '$dependency', but '$dependency' is not enabled for platform: $PLATFORM"
			return 1
			;;
		*)
			return 1
			;;
		esac

		expand_selected_group_dependencies_recursive "$dependency" || return 1
	done
}

expand_selected_group_dependencies() {
	local initial_groups=()
	local group

	initial_groups=("${SELECTED_GROUPS[@]}")
	for group in "${initial_groups[@]}"; do
		expand_selected_group_dependencies_recursive "$group" || return 1
	done
}

visit_group_for_validation() {
	local group="$1"
	local dependency

	if list_contains_word "$VISITED_GROUPS" "$group"; then
		return 0
	fi

	if list_contains_word "$VISITING_GROUPS" "$group"; then
		print_error "Detected a cycle in group metadata around: $group"
		return 1
	fi

	VISITING_GROUPS="${VISITING_GROUPS}${VISITING_GROUPS:+ }$group"

	load_group_metadata "$group" || return 1
	for dependency in $GROUP_DEPENDS_ON; do
		if ! group_exists "$dependency"; then
			print_error "Unknown dependency '$dependency' in $(group_metadata_path "$group")"
			return 1
		fi

		visit_group_for_validation "$dependency" || return 1
	done

	VISITING_GROUPS="$(remove_word_from_list "$VISITING_GROUPS" "$group")"
	VISITED_GROUPS="${VISITED_GROUPS}${VISITED_GROUPS:+ }$group"
}

validate_group_platform_dependencies() {
	local group="$1"
	local dependency
	local target_platform
	local rc=0

	load_group_metadata "$group" || return 1
	for dependency in $GROUP_DEPENDS_ON; do
		for target_platform in macos linux windows bsd; do
			group_supports_platform_for "$group" "$target_platform"
			rc=$?
			case "$rc" in
			0) ;;
			1)
				continue
				;;
			*)
				return 1
				;;
			esac

			group_supports_platform_for "$dependency" "$target_platform"
			rc=$?
			case "$rc" in
			0) ;;
			1)
				print_error "Group '$group' depends on '$dependency', but '$dependency' is not enabled for platform: $target_platform"
				return 1
				;;
			*)
				return 1
				;;
			esac
		done
	done
}

validate_all_group_metadata() {
	local group

	discover_all_groups
	if [ ${#ALL_GROUPS[@]} -eq 0 ]; then
		print_warning "No configuration groups found in Configs/"
		return 0
	fi

	for group in "${ALL_GROUPS[@]}"; do
		load_group_metadata "$group" || return 1
		validate_group_platform_dependencies "$group" || return 1
	done

	VISITING_GROUPS=""
	VISITED_GROUPS=""
	for group in "${ALL_GROUPS[@]}"; do
		visit_group_for_validation "$group" || return 1
	done

	print_success "Group metadata is valid"
}

visit_group_for_ordering() {
	local group="$1"
	local dependency

	if list_contains_word "$VISITED_GROUPS" "$group"; then
		return 0
	fi

	if list_contains_word "$VISITING_GROUPS" "$group"; then
		print_error "Detected a cycle in group metadata around: $group"
		return 1
	fi

	VISITING_GROUPS="${VISITING_GROUPS}${VISITING_GROUPS:+ }$group"

	load_group_metadata "$group" || return 1
	for dependency in $GROUP_DEPENDS_ON; do
		if ! array_contains SELECTED_GROUPS "$dependency"; then
			print_error "Group '$group' depends on '$dependency', but '$dependency' was not selected for deployment"
			return 1
		fi

		visit_group_for_ordering "$dependency" || return 1
	done

	VISITING_GROUPS="$(remove_word_from_list "$VISITING_GROUPS" "$group")"
	VISITED_GROUPS="${VISITED_GROUPS}${VISITED_GROUPS:+ }$group"
	append_unique_array_item ORDERED_GROUPS "$group"
}

sort_selected_groups_by_phase() {
	local early_groups=()
	local normal_groups=()
	local late_groups=()
	local group

	for group in "${SELECTED_GROUPS[@]}"; do
		load_group_metadata "$group" || return 1
		case "$GROUP_PHASE" in
		early | bootstrap)
			early_groups+=("$group")
			;;
		late)
			late_groups+=("$group")
			;;
		*)
			normal_groups+=("$group")
			;;
		esac
	done

	SELECTED_GROUPS=("${early_groups[@]}" "${normal_groups[@]}" "${late_groups[@]}")
}

order_selected_groups_by_dependencies() {
	local group

	ORDERED_GROUPS=()
	VISITING_GROUPS=""
	VISITED_GROUPS=""

	sort_selected_groups_by_phase || return 1
	for group in "${SELECTED_GROUPS[@]}"; do
		visit_group_for_ordering "$group" || return 1
	done
}

resolve_groups_for_preset() {
	local preset="$1"
	local group
	local rc=0

	SELECTED_GROUPS=()
	discover_all_groups

	for group in "${ALL_GROUPS[@]}"; do
		if group_supports_platform "$group"; then
			rc=0
		else
			rc=$?
		fi
		case "$rc" in
		0) ;;
		1)
			continue
			;;
		*)
			return 1
			;;
		esac

		if preset_group_matches "$group" "$preset"; then
			rc=0
		else
			rc=$?
		fi
		case "$rc" in
		0)
			append_unique_array_item SELECTED_GROUPS "$group"
			;;
		1) ;;
		*)
			return 1
			;;
		esac
	done

	if [ ${#SELECTED_GROUPS[@]} -eq 0 ]; then
		print_error "No configuration groups matched preset '$preset' on platform '$PLATFORM'"
		return 1
	fi

	expand_selected_group_dependencies || return 1
	order_selected_groups_by_dependencies || return 1
}

resolve_explicit_groups() {
	local requested_groups="$1"
	local group
	local dependency

	ORDERED_GROUPS=()
	IFS=',' read -r -a ORDERED_GROUPS <<<"$requested_groups"

	for group in "${ORDERED_GROUPS[@]}"; do
		if ! group_exists "$group"; then
			print_error "Unknown configuration group: $group"
			return 1
		fi
	done

	for group in "${ORDERED_GROUPS[@]}"; do
		load_group_metadata "$group" || return 1
		for dependency in $GROUP_DEPENDS_ON; do
			if ! array_contains ORDERED_GROUPS "$dependency"; then
				print_warning "Explicit group selection omits dependency '$dependency' required by '$group'"
			fi
		done
	done
}
