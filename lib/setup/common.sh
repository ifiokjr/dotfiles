#!/usr/bin/env bash

list_contains_word() {
	local list="${1:-}"
	local word="$2"

	case " $list " in
	*" $word "*)
		return 0
		;;
	*)
		return 1
		;;
	esac
}

array_contains() {
	local array_name="$1"
	local needle="$2"
	local value
	local values=()

	eval "values=(\"\${${array_name}[@]-}\")"
	for value in "${values[@]}"; do
		if [ "$value" = "$needle" ]; then
			return 0
		fi
	done

	return 1
}

append_unique_array_item() {
	local array_name="$1"
	local value="$2"

	if array_contains "$array_name" "$value"; then
		return 0
	fi

	eval "${array_name}+=(\"\$value\")"
}

remove_word_from_list() {
	local list="${1:-}"
	local word="$2"
	local result=""
	local item

	for item in $list; do
		if [ "$item" = "$word" ]; then
			continue
		fi
		result="${result}${result:+ }$item"
	done

	printf '%s\n' "$result"
}

join_array_by() {
	local array_name="$1"
	local separator="$2"
	local result=""
	local value

	eval "set -- \"\${${array_name}[@]}\""
	for value in "$@"; do
		result="${result}${result:+$separator}$value"
	done

	printf '%s\n' "$result"
}
