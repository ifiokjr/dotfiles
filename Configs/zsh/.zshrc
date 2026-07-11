# .zshrc - Zsh interactive shell configuration

# ---------------------------------------------------------------------------
# Cached init: source the output of `cmd args…` from a cache file instead of
# forking + eval every shell launch. Regenerates when the binary changes
# (path or mtime) or cache is >24h old. Falls back gracefully on failure.
# ---------------------------------------------------------------------------
_zsh_init_cache="$HOME/.cache/zsh-init"

# _zsh_cached <name> <cmd> [args…] — cache and source init output
_zsh_cached() {
	local name="$1"; shift
	local cache_file="$_zsh_init_cache/$name.zsh"
	local version_file="$_zsh_init_cache/$name.version"
	local cmd_path
	cmd_path="$(command -v "$1" 2>/dev/null)" || return 0

	local needs_regen=0
	if [[ ! -f "$cache_file" ]]; then
		needs_regen=1
	elif [[ -f "$version_file" ]]; then
		local cached_path cached_mtime
		{ IFS= read -r cached_path; IFS= read -r cached_mtime; } < "$version_file"
		if [[ "$cached_path" != "$cmd_path" ]]; then
			needs_regen=1
		else
			# Use zsh's built-in zstat (no subshell fork needed)
			zmodload -F zsh/stat b:zstat 2>/dev/null
			local current_mtime
			current_mtime="$(zstat +mtime "$cmd_path" 2>/dev/null)" || current_mtime=0
			[[ "$cached_mtime" != "$current_mtime" ]] && needs_regen=1
		fi
	else
		# No version file — check cache age via modification time
		zmodload -F zsh/stat b:zstat 2>/dev/null
		local cache_mtime
		cache_mtime="$(zstat +mtime "$cache_file" 2>/dev/null)" || cache_mtime=0
		(( EPOCHSECONDS - cache_mtime > 86400 )) && needs_regen=1
	fi

	if (( needs_regen )); then
		mkdir -p "$_zsh_init_cache"
		"$@" > "$cache_file" 2>/dev/null || { rm -f "$cache_file"; return 0; }
		zmodload -F zsh/stat b:zstat 2>/dev/null
		local current_mtime
		current_mtime="$(zstat +mtime "$cmd_path" 2>/dev/null)" || current_mtime=0
		printf '%s\n%s\n' "$cmd_path" "$current_mtime" > "$version_file"
	fi

	# shellcheck disable=SC1090
	source "$cache_file"
}

# ---------------------------------------------------------------------------
# Debug profiling (zero-cost when DOTFILES_DEBUG is unset)
# ---------------------------------------------------------------------------
if [[ -n "$DOTFILES_DEBUG" ]]; then
	zmodload zsh/datetime
	# Use the earliest timestamp from .zshenv if available, otherwise start now
	[[ -z "$_zsh_earliest_ns" ]] && _zsh_earliest_ns=$EPOCHREALTIME
	_zsh_start_ns=$_zsh_earliest_ns
	_zsh_ts() {
		local elapsed_ms
		elapsed_ms=$(( (EPOCHREALTIME - _zsh_start_ns) * 1000 ))
		printf "  \e[1m%-35s\e[0m %7.0f ms\n" "$1" "$elapsed_ms"
	}
	printf '\e[34m→\e[0m zsh profiling enabled\n'
	[[ -n "$_zsh_earliest_ns" ]] && _zsh_ts "(.zshenv)"
	[[ -n "$_zsh_zprofile_ts" ]] && _zsh_ts "(.zprofile)"
else
	_zsh_ts() { :; }
fi

# ---------------------------------------------------------------------------
# Shared environment (PATH, env vars, secrets)
# ---------------------------------------------------------------------------
# shellcheck disable=SC1091
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "env.sh"

# Return early for non-interactive shells
[[ $- != *i* ]] && return

# ---------------------------------------------------------------------------
# Shell options
# ---------------------------------------------------------------------------
setopt AUTO_CD              # cd by typing directory name
setopt SHARE_HISTORY        # Share history between sessions
setopt HIST_IGNORE_ALL_DUPS # Remove older duplicate entries
setopt HIST_REDUCE_BLANKS   # Remove unnecessary blanks
setopt HIST_VERIFY          # Don't execute immediately on history expansion
setopt APPEND_HISTORY       # Append to history
setopt INC_APPEND_HISTORY   # Write to history file immediately
setopt CORRECT              # Spelling correction for commands
setopt NO_BEEP              # No bell on error
setopt GLOB_DOTS            # Include dotfiles in globbing

# History
HISTSIZE=50000
SAVEHIST=50000
HISTFILE="$HOME/.zsh_history"

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------
autoload -Uz compinit

# Regenerate completion dump daily (avoids slow startup from compinit -C)
_comp_dump="$HOME/.zcompdump"
if [[ -f "$_comp_dump" && $(date +'%j') != $(date -r "$_comp_dump" +'%j' 2>/dev/null) ]]; then
	compinit
else
	compinit -C
fi
unset _comp_dump
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "compinit"

# Case-insensitive and partial matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select

# Carapace completions (richer than default zsh)
if command -v carapace &>/dev/null; then
	export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
	_zsh_cached carapace carapace _carapace
fi
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "carapace"

# ---------------------------------------------------------------------------
# Tool integrations — all use cached init for speed
# ---------------------------------------------------------------------------
if command -v direnv &>/dev/null; then
	_zsh_cached direnv direnv hook zsh
fi
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "direnv hook"

if command -v devenv &>/dev/null; then
	_zsh_cached devenv devenv hook zsh
fi
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "devenv hook"

if command -v starship &>/dev/null; then
	# Lazy-load starship: set a minimal prompt, then load starship on first precmd.
	# This saves ~130ms of startup by deferring starship init until the first prompt.
	PS1='%F{cyan}%~%f %# '
	_lazy_starship_loaded=0
	_lazy_starship_load() {
		if (( _lazy_starship_loaded )); then return; fi
		_lazy_starship_loaded=1
		_zsh_cached starship starship init zsh
		# Remove ourselves from precmd after first call
		add-zsh-hook -d precmd _lazy_starship_load
	}
	autoload -Uz add-zsh-hook
	add-zsh-hook precmd _lazy_starship_load
fi
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "starship (lazy)"

if command -v zoxide &>/dev/null; then
	_zsh_cached zoxide zoxide init zsh
fi
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "zoxide init"

if command -v atuin &>/dev/null; then
	# Lazy-load atuin: defer init until first keypress.
	# This saves ~160ms of startup by deferring atuin until the user actually types.
	_lazy_atuin_loaded=0
	_lazy_atuin_load() {
		if (( _lazy_atuin_loaded )); then return; fi
		_lazy_atuin_loaded=1
		_zsh_cached atuin atuin init zsh
		# Remove ourselves from the zle hook
		zle -N _lazy_atuin_widget _lazy_atuin_load
		zle -D _lazy_atuin_widget 2>/dev/null
		bindkey -M emacs '' _lazy_atuin_widget 2>/dev/null
		bindkey -M viins '' _lazy_atuin_widget 2>/dev/null
	}
	# Create a widget that triggers atuin load on first keypress
	zle -N _lazy_atuin_widget _lazy_atuin_load
	# Bind common keys to trigger the lazy load
	bindkey -M emacs '^[OA' _lazy_atuin_widget 2>/dev/null
	bindkey -M emacs '^[OB' _lazy_atuin_widget 2>/dev/null
	bindkey -M emacs '^R' _lazy_atuin_widget 2>/dev/null
	bindkey -M viins '^R' _lazy_atuin_widget 2>/dev/null
	bindkey -M viins '^[OA' _lazy_atuin_widget 2>/dev/null
	bindkey -M viins '^[OB' _lazy_atuin_widget 2>/dev/null
fi
[[ -n "$DOTFILES_DEBUG" ]] && _zsh_ts "atuin (lazy)"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
# Editors
alias vim='nvim'
alias n='nvim'
alias co='codex --dangerously-bypass-approvals-and-sandbox'

# General
alias cl='clear'
alias md='mkdir'
alias rd='rmdir'
alias zj='zellij'
alias lg='lazygit'

# lsd (ls replacement)
if command -v lsd &>/dev/null; then
	alias l='lsd -lah'
	alias la='lsd -lAh'
	alias ll='lsd -lh'
	alias lls='lsd -G'
	alias lsa='lsd -lah'
fi

# Nix
alias nr='rebuild'
alias nfc='nix flake check --flake ~/.config/nix'
alias nfu='nix flake update --flake ~/.config/nix'
alias ns='nix search nixpkgs'

# Git
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gb='git branch'
alias gc='git commit --verbose'
alias gcb='git checkout -b'
alias gcmsg='git commit --message'
alias gco='git checkout'
alias gd='git diff'
alias gf='git fetch'
alias gfa='git fetch --all --tags --prune --jobs=10'
alias gl='git pull'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gm='git merge'
alias gp='git push'
alias gpf='git push --force-with-lease --force-if-includes'
alias gp!='git push --force-with-lease --force-if-includes'
alias gpr='git pull --rebase'
alias grb='git rebase'
alias grs='git restore'
alias grst='git restore --staged'
alias gsb='git status --short --branch'
alias gss='git status --short'
alias gst='git status'
alias gsta='git stash push'
alias gstp='git stash pop'
alias gsw='git switch'
alias gswc='git switch --create'

# ---------------------------------------------------------------------------
# Startup summary (only when DOTFILES_DEBUG is set)
# ---------------------------------------------------------------------------
[[ -n "$DOTFILES_DEBUG" ]] && printf '\e[34m→\e[0m zsh total: %0.0f ms\n' "$(( (EPOCHREALTIME - _zsh_start_ns) * 1000 ))"