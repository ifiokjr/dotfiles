# shellcheck shell=bash
# .bashrc - Bash interactive shell configuration

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
shopt -s histappend     # Append to history, don't overwrite
shopt -s cdspell        # Autocorrect minor typos in cd
shopt -s dirspell       # Autocorrect directory names during completion
shopt -s checkwinsize   # Update LINES/COLUMNS after each command
shopt -s globstar       # ** matches recursively
shopt -s nocaseglob     # Case-insensitive globbing

# History
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups

# ---------------------------------------------------------------------------
# Tool integrations (all guarded by command -v)
# ---------------------------------------------------------------------------
if command -v direnv &>/dev/null; then
	eval "$(direnv hook bash)"
fi

if command -v starship &>/dev/null; then
	eval "$(starship init bash)"
fi

if command -v zoxide &>/dev/null; then
	eval "$(zoxide init bash)"
fi

if command -v atuin &>/dev/null; then
	eval "$(atuin init bash)"
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
# Editors
alias vim='nvim'
alias n='nvim'
alias cc='claude --dangerously-skip-permissions'
alias co='codex --dangerously-bypass-approvals-and-sandbox'
alias oc='opencode'

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

export PATH="$HOME/.local/bin:$PATH"
