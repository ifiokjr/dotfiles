#!/usr/bin/env bash

verify_success() {
	VERIFY_SUCCESSES=$((VERIFY_SUCCESSES + 1))
	print_success "$1"
}

verify_warning() {
	VERIFY_WARNINGS=$((VERIFY_WARNINGS + 1))
	print_warning "$1"
}

verification_tuckr_path() {
	case "$PLATFORM" in
	macos)
		printf '%s\n' "$HOME/Library/Application Support/dotfiles"
		;;
	linux | bsd | windows)
		printf '%s\n' "$HOME/.config/dotfiles"
		;;
	esac
}

run_setup_verification() {
	local tuckr_path
	local target

	VERIFY_SUCCESSES=0
	VERIFY_WARNINGS=0

	print_header "Setup verification"

	if command_exists nix && nix --version >/dev/null 2>&1; then
		verify_success "Nix installed"
	else
		verify_warning "Nix is not responding"
	fi

	tuckr_path="$(verification_tuckr_path)"
	if [ -L "$tuckr_path" ]; then
		target="$(readlink "$tuckr_path")"
		if [ "$target" = "$DOTFILES_DIR" ]; then
			verify_success "Tuckr symlink configured"
		else
			verify_warning "Tuckr symlink points to $target instead of $DOTFILES_DIR"
		fi
	else
		verify_warning "Tuckr symlink not found at $tuckr_path"
	fi

	if command_exists tuckr; then
		verify_success "Tuckr available"
		if tuckr status >/dev/null 2>&1; then
			verify_success "Tuckr status command succeeded"
		else
			verify_warning "tuckr status reports undeployed groups or warnings"
		fi
	else
		verify_warning "Tuckr is not on PATH"
	fi

	if command_exists nu; then
		verify_success "Nushell available"
	else
		verify_warning "Nushell is not on PATH yet; open a new terminal after setup"
	fi

	if array_contains ORDERED_GROUPS nushell; then
		if [ -L "$HOME/.config/nushell/config.nu" ]; then
			verify_success "Nushell symlink present"
		else
			verify_warning "Expected Nushell config symlink is missing"
		fi
	fi

	if array_contains ORDERED_GROUPS helix; then
		if [ -L "$HOME/.config/helix/config.toml" ]; then
			verify_success "Helix symlink present"
		else
			verify_warning "Expected Helix config symlink is missing"
		fi
	fi

	if array_contains ORDERED_GROUPS zsh; then
		if [ -L "$HOME/.zshrc" ]; then
			verify_success "Zsh symlink present"
		else
			verify_warning "Expected ~/.zshrc symlink is missing"
		fi
	fi

	if array_contains ORDERED_GROUPS nix; then
		if command_exists rebuild; then
			verify_success "rebuild command available"
		else
			verify_warning "rebuild command is not on PATH yet"
		fi
	fi

	echo ""
	if [ "$VERIFY_WARNINGS" -gt 0 ]; then
		print_warning "Verification completed with $VERIFY_WARNINGS warning(s)"
	else
		print_success "Verification completed with $VERIFY_SUCCESSES successful checks"
	fi
}
