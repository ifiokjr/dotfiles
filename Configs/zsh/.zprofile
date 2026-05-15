# .zprofile - Zsh login shell configuration
# nix-darwin's /etc/zshenv already handles nix PATH setup, so this file
# is intentionally minimal. Add login-only setup here if needed.

# Debug: capture .zprofile time for later display by .zshrc profiler
[[ -n "${DOTFILES_DEBUG:-}" ]] && _zsh_zprofile_ts=$EPOCHREALTIME
