
# Debug: capture earliest start time (zero-cost when DOTFILES_DEBUG unset)
[[ -n "${DOTFILES_DEBUG:-}" ]] && zmodload zsh/datetime && _zsh_earliest_ns=$EPOCHREALTIME

export PATH="$PATH:/Users/ifiokjr/.foundry/bin"
. "$HOME/.cargo/env"

# mr boxington (mbx): every Rust build goes through the shared build cache.
# Prepended after rustup's env so the shim wins over ~/.cargo/bin for all zsh
# shells, including the non-interactive ones agents and scripts use. The shim
# falls back to `mbx` on PATH, and is a no-op where mbx is not installed.
if [ -x "$HOME/Library/Application Support/mbx/bin/cargo" ]; then
	export PATH="$HOME/Library/Application Support/mbx/bin:$PATH"
fi

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
