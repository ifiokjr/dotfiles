# Debug: capture earliest start time (zero-cost when DOTFILES_DEBUG unset)
[[ -n "${DOTFILES_DEBUG:-}" ]] && zmodload zsh/datetime && _zsh_earliest_ns=$EPOCHREALTIME

# zshenv runs for every zsh shell, so everything below is guarded: a missing
# tool must not print an error into every agent and script shell.
[[ -d "$HOME/.foundry/bin" ]] && export PATH="$PATH:$HOME/.foundry/bin"
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

# mr boxington (mbx): every Rust build goes through the shared build cache.
# Prepended after rustup's env so the shim wins over ~/.cargo/bin for all zsh
# shells, including the non-interactive ones agents and scripts use. The shim
# falls back to `mbx` on PATH, and is a no-op where mbx is not installed.
# The case guard keeps nested shells (agents spawn many) from stacking
# duplicate entries.
if [ -x "$HOME/Library/Application Support/mbx/bin/cargo" ]; then
	case ":$PATH:" in
	*":$HOME/Library/Application Support/mbx/bin:"*) ;;
	*) export PATH="$HOME/Library/Application Support/mbx/bin:$PATH" ;;
	esac
fi

# Android SDK: agents build and test Android apps from non-interactive shells,
# which never read .zshrc (and so never reach env.sh).
[[ -f "$HOME/.config/shell/android.sh" ]] && . "$HOME/.config/shell/android.sh"

# Vite+ bin (https://viteplus.dev)
[[ -f "$HOME/.vite-plus/env" ]] && . "$HOME/.vite-plus/env"
