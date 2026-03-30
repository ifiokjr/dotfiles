#!/usr/bin/env bash

run_doctor() {
	local problems=0
	local warnings=0
	local available_kb
	local target_dir
	local tuckr_path

	print_header "Dotfiles Doctor"

	print_success "Platform supported: $PLATFORM"

	if command_exists curl; then
		print_success "curl available"
	else
		print_error "curl is required for bootstrap and is not installed"
		problems=$((problems + 1))
	fi

	if can_run_git; then
		print_success "Git available"
	elif [ "$PLATFORM" = "macos" ]; then
		print_warning "Git is not runnable yet; setup can fall back to Nix, but Command Line Tools may still be missing"
		warnings=$((warnings + 1))
	else
		print_warning "Git is not installed; setup can install it temporarily after Nix"
		warnings=$((warnings + 1))
	fi

	if command_exists sudo; then
		if sudo -n true 2>/dev/null; then
			print_success "sudo available without prompting"
		else
			print_info "sudo available (setup may prompt when applying system changes)"
		fi
	else
		print_warning "sudo not found; some setup paths may not work"
		warnings=$((warnings + 1))
	fi

	if command_exists nix && nix --version >/dev/null 2>&1; then
		print_success "Nix installed and responding"
	else
		print_info "Nix not installed (setup can install it unless --skip-nix is used)"
	fi

	if [ "$PLATFORM" = "macos" ]; then
		if xcode-select -p >/dev/null 2>&1; then
			print_success "Xcode Command Line Tools installed"
		else
			print_warning "Xcode Command Line Tools are not installed yet"
			warnings=$((warnings + 1))
		fi
	fi

	available_kb="$(df -Pk "$HOME" | awk 'NR==2 { print $4 }')"
	if [ -n "$available_kb" ] && [ "$available_kb" -lt 10485760 ]; then
		print_warning "Less than 10 GiB free in the home filesystem; large Nix builds may fail"
		warnings=$((warnings + 1))
	else
		print_success "Sufficient free disk space detected"
	fi

	if [ -n "${GITHUB_TOKEN:-}" ]; then
		print_success "GITHUB_TOKEN is set"
	else
		print_warning "GITHUB_TOKEN is not set; GitHub-backed fetches may be rate limited"
		warnings=$((warnings + 1))
	fi

	if [ -n "$DOTFILES_DIR" ]; then
		target_dir="$DOTFILES_DIR"
	else
		target_dir="$DEFAULT_DOTFILES_DIR"
	fi

	if mkdir -p "$(dirname "$target_dir")" 2>/dev/null; then
		print_success "Dotfiles parent directory is writable: $(dirname "$target_dir")"
	else
		print_error "Cannot write to the dotfiles parent directory: $(dirname "$target_dir")"
		problems=$((problems + 1))
	fi

	case "$PLATFORM" in
	macos)
		tuckr_path="$HOME/Library/Application Support/dotfiles"
		;;
	linux | bsd)
		tuckr_path="$HOME/.config/dotfiles"
		;;
	windows)
		tuckr_path="$HOME/.config/dotfiles"
		;;
	esac

	if mkdir -p "$(dirname "$tuckr_path")" 2>/dev/null; then
		print_success "Tuckr symlink parent directory is writable: $(dirname "$tuckr_path")"
	else
		print_error "Cannot write to the Tuckr symlink parent directory: $(dirname "$tuckr_path")"
		problems=$((problems + 1))
	fi

	if command_exists curl && curl --head --silent --fail --location https://github.com >/dev/null 2>&1; then
		print_success "GitHub reachable"
	else
		print_warning "GitHub could not be reached during the preflight check"
		warnings=$((warnings + 1))
	fi

	echo ""
	if [ "$problems" -gt 0 ]; then
		print_error "Doctor found $problems blocking issue(s) and $warnings warning(s)"
		return 1
	fi

	if [ "$warnings" -gt 0 ]; then
		print_warning "Doctor found $warnings warning(s), but no blocking issues"
	else
		print_success "Doctor found no obvious blockers"
	fi
}
