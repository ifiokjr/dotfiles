#!/usr/bin/env bash

run_tuckr_command() {
	local tuckr_bin="$1"
	local mode="$2"
	local group="$3"
	local force="${4:-false}"
	local out_file
	local rc=0

	out_file="$(mktemp)"

	if [ "$force" = true ]; then
		if echo y | "$tuckr_bin" "$mode" --force "$group" 2>&1 | tee "$out_file"; then
			rc=0
		else
			rc=$?
		fi
	else
		if "$tuckr_bin" "$mode" "$group" 2>&1 | tee "$out_file"; then
			rc=0
		else
			rc=$?
		fi
	fi

	if grep -q "Failed to hook" "$out_file"; then
		if [ "${SETUP_ALLOW_NIX_HOOK_FAILURE:-false}" = "true" ] && [ "$group" = "nix" ] && [ "$mode" = "set" ]; then
			print_warning "Ignoring nix hook failure due to SETUP_ALLOW_NIX_HOOK_FAILURE=true"
			rm -f "$out_file"
			return 0
		fi

		rm -f "$out_file"
		return 2
	fi

	rm -f "$out_file"
	return "$rc"
}

tuckr_deploy() {
	local tuckr_bin="$1"
	local group="$2"
	local mode="$3"
	local rc=0

	if run_tuckr_command "$tuckr_bin" "$mode" "$group"; then
		return 0
	else
		rc=$?
	fi

	if [ "$rc" -eq 2 ]; then
		print_error "Hook failed while deploying $group"
		return 1
	fi

	print_warning "Retrying $group with --force (existing file conflict)"
	if run_tuckr_command "$tuckr_bin" "$mode" "$group" true; then
		return 0
	else
		rc=$?
	fi

	if [ "$rc" -eq 2 ]; then
		print_error "Hook failed while deploying $group"
	fi

	return 1
}

prepare_tuckr_parent_directories() {
	local group_dir="$1"
	local dir
	local rel

	while IFS= read -r -d '' dir; do
		rel="${dir#"${group_dir}"/}"
		mkdir -p "$HOME/$rel"
	done < <(find "$group_dir" -mindepth 2 -type d -print0)
}

deploy_single_group() {
	local tuckr_bin="$1"
	local group="$2"
	local mode

	mode="$(group_deploy_mode "$group")"
	if [ "$mode" = "set" ]; then
		print_info "Deploying $group (with hooks)"
	else
		print_info "Deploying $group"
	fi

	if [ "$group" = "nix" ]; then
		echo ""
		if [ "$PLATFORM" = "macos" ]; then
			print_header "Nix Darwin Configuration"
			echo -e "${YELLOW}Note:${NC} nix deployment will run 'nh darwin switch' which requires sudo"
		else
			print_header "Nix Home Manager Configuration"
			echo -e "${YELLOW}Note:${NC} nix deployment will run 'nh home switch'"
		fi
		print_info "This may take several minutes..."
		echo ""

		if [ "$PLATFORM" != "macos" ]; then
			if [ "$INSTALLED_TUCKR" = true ]; then
				print_info "Removing temporary tuckr to avoid nix profile conflict"
				run_nix profile remove --regex '.*tuckr.*' 2>/dev/null || true
				INSTALLED_TUCKR=false
			fi
			if [ "$INSTALLED_NUSHELL" = true ]; then
				print_info "Removing temporary nushell to avoid nix profile conflict"
				run_nix profile remove --regex '.*nushell.*' 2>/dev/null || true
				INSTALLED_NUSHELL=false
			fi
		fi
	fi

	if tuckr_deploy "$tuckr_bin" "$group" "$mode"; then
		if [ "$group" = "nix" ] && [ "$PLATFORM" != "macos" ] && ! command_exists nu; then
			print_info "Re-installing temporary nushell after nix deployment"
			install_nushell
		fi
		print_success "Deployed $group"
	else
		print_error "Failed to deploy $group"
		DEPLOY_FAILED=true
		return 1
	fi

	return 0
}

maybe_install_custom_helix() {
	local helix_install_script
	local tool

	echo ""
	print_header "Custom Helix with Steel Plugin System"
	echo -e "${YELLOW}Note:${NC} The helix config has been deployed, but you need the custom Helix binary to use Steel plugins"
	print_info "This will:"
	echo "  • Clone/update the Helix Steel fork (mattwparas/helix)"
	echo "  • Build Helix with Steel plugin support (requires Rust/cargo)"
	echo "  • Install Steel language server, package manager, and forge plugins"
	echo "  • Install scooter.hx (interactive find-and-replace plugin)"
	echo "  • This process takes 5-10 minutes"
	echo ""

	if [ "$NO_CONFIRM" = false ] && ask_yes_no "Would you like to install custom Helix with Steel support now?"; then
		print_info "Installing custom Helix..."
		echo ""

		helix_install_script="$DOTFILES_DIR/Configs/scripts/.local/bin/install:helix:custom"
		if [ -f "$helix_install_script" ]; then
			if nu "$helix_install_script"; then
				print_success "Custom Helix installed successfully"
				for tool in forge steel steel-language-server; do
					if [ -f "$HOME/.local/bin/$tool" ]; then
						print_success "$tool available at ~/.local/bin/$tool"
					else
						print_warning "$tool not found at ~/.local/bin/$tool"
					fi
				done
			else
				print_warning "Failed to install custom Helix (you can run 'install:helix:custom' manually later)"
			fi
		else
			print_warning "install:helix:custom script not found (you can run it manually after setup)"
		fi
	else
		print_info "Skipping custom Helix installation"
		print_info "You can install it later by running: install:helix:custom"
	fi
	echo ""
}

trim_ordered_groups_from_target() {
	local target="$1"
	local filtered_groups=()
	local seen_target=false
	local group

	for group in "${ORDERED_GROUPS[@]}"; do
		if [ "$seen_target" = false ] && [ "$group" = "$target" ]; then
			seen_target=true
		fi
		if [ "$seen_target" = true ]; then
			filtered_groups+=("$group")
		fi
	done

	if [ "$seen_target" = false ]; then
		print_error "Could not resume from unknown deployment group: $target"
		return 1
	fi

	ORDERED_GROUPS=("${filtered_groups[@]}")
}

resolve_requested_groups() {
	if [ -n "$DEPLOY_GROUPS" ]; then
		resolve_explicit_groups "$DEPLOY_GROUPS"
		return $?
	fi

	resolve_groups_for_preset "$PRESET"
}

deploy_groups() {
	local tuckr_bin
	local group

	print_header "Deploying configuration groups"

	cd "$DOTFILES_DIR" || return 1

	if ! resolve_requested_groups; then
		return 1
	fi

	for group in "${ORDERED_GROUPS[@]}"; do
		prepare_tuckr_parent_directories "$DOTFILES_DIR/Configs/$group"
	done

	tuckr_bin="$(realpath "$(command -v tuckr)")"

	print_info "Deployment order: $(join_array_by ORDERED_GROUPS ', ')"
	echo ""

	if [ -n "$FROM_TARGET" ] && group_exists "$FROM_TARGET"; then
		trim_ordered_groups_from_target "$FROM_TARGET" || return 1
		print_info "Resuming deployment from group: $FROM_TARGET"
	fi

	DEPLOY_FAILED=false
	FIRST_FAILED_GROUP=""
	for group in "${ORDERED_GROUPS[@]}"; do
		write_setup_phase "deploy:$group"
		if [ -n "$PRESET" ]; then
			group_supports_platform "$group"
			case $? in
			0) ;;
			1)
				print_info "Skipping $group (not enabled for platform: $PLATFORM)"
				continue
				;;
			*)
				return 1
				;;
			esac
		fi

		if ! deploy_single_group "$tuckr_bin" "$group"; then
			if [ -z "$FIRST_FAILED_GROUP" ]; then
				FIRST_FAILED_GROUP="$group"
			fi
			continue
		fi

		if [ "$group" = "helix" ]; then
			maybe_install_custom_helix
		fi
	done

	echo ""
	if [ "$DEPLOY_FAILED" = true ]; then
		if [ -n "$FIRST_FAILED_GROUP" ]; then
			write_setup_phase "deploy:$FIRST_FAILED_GROUP"
		fi
		print_error "Some groups failed to deploy (see errors above)"
		return 1
	fi

	print_success "Configuration deployment complete"
}
