# shellcheck shell=bash
# .zshrc - Zsh configuration
# Sources shared environment from ~/.config/shell/env.sh and adds
# zsh-specific integrations (starship, direnv, atuin, zoxide, etc.)

# ---------------------------------------------------------------------------
# Shared environment (PATH, nix bootstrap, env vars, secrets)
# ---------------------------------------------------------------------------
if [ -f "$HOME/.config/shell/env.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/env.sh"
    load_dotfiles_secrets
fi

# ---------------------------------------------------------------------------
# Interactive shell only — exit early for non-interactive sessions
# ---------------------------------------------------------------------------
[[ -o interactive ]] || return

# ---------------------------------------------------------------------------
# Zsh options
# ---------------------------------------------------------------------------
setopt AUTO_CD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT
setopt HIST_APPEND
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt EXTENDED_GLOB
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

# History
HISTSIZE=100000
SAVEHIST=200000
HISTFILE="$HOME/.zsh_history"

# ---------------------------------------------------------------------------
# Completion system
# ---------------------------------------------------------------------------
autoload -Uz compinit
# Only regenerate completion dump once per day for performance
# shellcheck disable=SC1036,SC1073,SC1009,SC1072
if [[ -n "$HOME/.zcompdump"(#qN.mh+24) ]]; then
    compinit
else
    compinit -C
fi
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ''

# ---------------------------------------------------------------------------
# Tool integrations (only if the tool is installed)
# ---------------------------------------------------------------------------

# Starship prompt
if (( $+commands[starship] )); then
    eval "$(starship init zsh)"
fi

# Direnv
if (( $+commands[direnv] )); then
    eval "$(direnv hook zsh)"
fi

# Atuin (shell history)
if (( $+commands[atuin] )); then
    eval "$(atuin init zsh)"
fi

# Zoxide (smart cd)
if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi

# Carapace (completions)
if (( $+commands[carapace] )); then
    export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
    zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
    # shellcheck disable=SC1090
    source <(carapace _carapace zsh)
fi

# Mise (runtime version manager)
if (( $+commands[mise] )); then
    eval "$(mise activate zsh)"
fi

# ---------------------------------------------------------------------------
# General aliases
# ---------------------------------------------------------------------------
alias s='exec zsh'
alias vim='nvim'
alias n='nvim'
alias zj='zellij'
alias lg='lazygit'
alias cl='clear'
alias cc='claude --dangerously-skip-permissions'
alias g='git'
alias md='mkdir -p'
alias rd='rmdir'

# ---------------------------------------------------------------------------
# Rust / Cargo
# ---------------------------------------------------------------------------
alias cr='cargo run'
alias cb='cargo build'
alias ct='cargo test'
alias cch='cargo check'
alias ccl='cargo clippy'
alias cf='cargo fmt'
alias cw='cargo watch -x run'

# ---------------------------------------------------------------------------
# pnpm / Node.js
# ---------------------------------------------------------------------------
alias p='pnpm'
alias pi='pnpm install'
alias pd='pnpm dev'
alias pb='pnpm build'
alias pt='pnpm test'
alias px='pnpm exec'
alias pa='pnpm add'
alias pad='pnpm add -D'
alias pr='pnpm run'

# ---------------------------------------------------------------------------
# Docker / Compose
# ---------------------------------------------------------------------------
alias dk='docker'
alias dkc='docker compose'
alias dkcu='docker compose up -d'
alias dkcd='docker compose down'
alias dkcl='docker compose logs -f'
alias dkce='docker compose exec'
alias dkps='docker ps'

# ---------------------------------------------------------------------------
# Nix / Devenv
# ---------------------------------------------------------------------------
alias nr='rebuild'
alias nfc='nix flake check --flake ~/.config/nix'
alias nfu='nix flake update --flake ~/.config/nix'
alias ns='nix search nixpkgs'
alias de='devenv up'

# ---------------------------------------------------------------------------
# File listing (lsd)
# ---------------------------------------------------------------------------
if (( $+commands[lsd] )); then
    alias l='lsd -lah'
    alias la='lsd -lAh'
    alias ll='lsd -lh'
    alias lls='lsd -G'
    alias lsa='lsd -lah'
else
    alias l='ls -lah'
    alias la='ls -lAh'
    alias ll='ls -lh'
    alias lsa='ls -lah'
fi

# ---------------------------------------------------------------------------
# Git aliases
# ---------------------------------------------------------------------------
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gc='git commit --verbose'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gd='git diff'
alias gdca='git diff --cached'
alias gds='git diff --staged'
alias gf='git fetch'
alias gfa='git fetch --all --tags --prune --jobs=10'
alias gl='git pull'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias gm='git merge'
alias gp='git push'
alias gpf='git push --force-with-lease --force-if-includes'
alias gpr='git pull --rebase'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grh='git reset'
alias grhh='git reset --hard'
alias grs='git restore'
alias grst='git restore --staged'
alias gsb='git status --short --branch'
alias gss='git status --short'
alias gst='git status'
alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsw='git switch'
alias gswc='git switch --create'

# ---------------------------------------------------------------------------
# Git helper functions
# ---------------------------------------------------------------------------
git_main_branch() {
    local branches
    branches=$(command git branch --list main master 2>/dev/null)
    if echo "$branches" | grep -q 'main'; then echo "main"
    elif echo "$branches" | grep -q 'master'; then echo "master"
    else echo "main"
    fi
}

git_current_branch() {
    command git branch --show-current 2>/dev/null
}

gcm() { git checkout "$(git_main_branch)"; }
ggpull() { git pull origin "$(git_current_branch)"; }
ggpush() { git push origin "$(git_current_branch)"; }
gpsup() { git push --set-upstream origin "$(git_current_branch)"; }
gpsupf() { git push --set-upstream origin "$(git_current_branch)" --force-with-lease --force-if-includes; }
grbm() { git rebase "$(git_main_branch)"; }
gswm() { git switch "$(git_main_branch)"; }
