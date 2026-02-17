# .zshrc - Zsh interactive shell configuration

# ---------------------------------------------------------------------------
# Shared environment (PATH, env vars, secrets)
# ---------------------------------------------------------------------------
# shellcheck disable=SC1091
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"

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

# Case-insensitive and partial matching
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' menu select

# Carapace completions (richer than default zsh)
if command -v carapace &>/dev/null; then
	export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
	source <(carapace _carapace)
fi

# ---------------------------------------------------------------------------
# Tool integrations (all guarded by command -v)
# ---------------------------------------------------------------------------
if command -v direnv &>/dev/null; then
	eval "$(direnv hook zsh)"
fi

if command -v starship &>/dev/null; then
	eval "$(starship init zsh)"
fi

if command -v zoxide &>/dev/null; then
	eval "$(zoxide init zsh)"
fi

if command -v atuin &>/dev/null; then
	eval "$(atuin init zsh)"
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
# Editors
alias vim='nvim'
alias n='nvim'
alias cc='claude --dangerously-skip-permissions'

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
