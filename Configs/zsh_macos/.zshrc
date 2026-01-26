# Profiling (uncomment to profile startup time)
# zmodload zsh/zprof

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Performance optimizations for Oh-My-Zsh
DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_UPDATE_PROMPT="true"

# Increase file descriptor limit for Nix builds
ulimit -n 10240

# Fix for rust builds
export MACOSX_DEPLOYMENT_TARGET="12.0"

# Make Yazelix's Yazi config your default (it's plugin-enhanced and adjusts layout based on width)
export YAZI_CONFIG_HOME="$HOME/.config/yazelix/yazi"

# Load secrets
__SECRETS_ENV="$HOME/.env.dotfiles"
[ -f $__SECRETS_ENV ] && set -a &&  source $__SECRETS_ENV && set +a

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Minimal plugin list for faster startup
plugins=(
  git
  macos
)

source $ZSH/oh-my-zsh.sh

# Completion system optimization - only rebuild once per day
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# deno
export DENO_INSTALL="$HOME/.deno"
export PATH="$DENO_INSTALL/bin:$PATH"

# Android
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/fvm/default/bin:$PATH"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/lastest/bin"
export PATH="$PATH:$ANDROID_HOME/platform-tools"
export PATH=$PATH:"/Applications/Android Studio.app/Contents/MacOS"
export NDK_HOME="~/Library/Android/sdk/ndk/29.0.13599879"

# llvm (cached to avoid repeated brew calls)
if [[ -z "$LLVM_PREFIX" ]]; then
  export LLVM_PREFIX="$(brew --prefix llvm 2>/dev/null || echo "/opt/homebrew/opt/llvm")"
fi
export LDFLAGS="-L$LLVM_PREFIX/lib"
export LIBCLANG_PATH="$LLVM_PREFIX/lib"
export LLVM_CONFIG_PATH="$LLVM_PREFIX/bin/llvm-config"
export CPPFLAGS="-I$LLVM_PREFIX/include"
export PATH="$LLVM_PREFIX/bin:$PATH"

# Editor configuration (cached to avoid repeated which calls)
export EDITOR='hx'
export SUDO_EDITOR='hx'

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias s="source $HOME/.zshrc"
alias update="nix flake update --flake $HOME/.config/nix"
alias rebuild="ulimit -n 10240 && sudo darwin-rebuild switch --flake ~/.config/nix#\$(whoami)"
alias vim="nvim"
alias n="nvim"
alias zj="zellij"
alias c="open $1 -a \"Cursor\""
alias lg="lazygit"
alias cl="clear"
alias bu="brew upgrade"
alias grH="git reset HEAD^"
alias gco1="gco -"
alias gco2="gco @{-2}"
alias gco3="gco @{-3}"
alias gco4="gco @{-4}"
alias gco5="gco @{-5}"
alias gw="git worktree"
alias gwh="git worktree --help"
alias gwa="git worktree add"
alias gwm="git worktree move"
alias gwr="git worktree remove"
alias gwl="git worktree list --porcelain"
alias gpnv!="gpf --no-verify"
alias gpfnv="gpnv!"
alias gpnv="gp --no-verify"
gsqa() { git reset $(git commit-tree HEAD^{tree} -m "$1") }
alias l='lsd -lah'
alias la='lsd -lAh'
alias ll='lsd -lh'
alias ls='lsd -G'
alias lsa='lsd -lah'
alias pinentry="pinentry-mac"
alias zshconfig="hx ~/.zshrc"
alias ohmyzsh="hx ~/.oh-my-zsh"

# Solana (single PATH addition)
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# GPG
export GPG_TTY=$(tty)

# direnv (lazy load for better performance)
export DIRENV_LOG_FORMAT=""
_direnv_hook() {
  eval "$(direnv export zsh)"
}
if ! command -v direnv &> /dev/null; then
  # direnv not installed, skip
  :
else
  typeset -ag precmd_functions
  if [[ -z ${precmd_functions[(r)_direnv_hook]} ]]; then
    precmd_functions=(_direnv_hook $precmd_functions)
  fi
  typeset -ag chpwd_functions
  if [[ -z ${chpwd_functions[(r)_direnv_hook]} ]]; then
    chpwd_functions=(_direnv_hook $chpwd_functions)
  fi
fi

 # Nix
 if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
 fi
 # End Nix

# pnpm (standalone version installed via Nix)
# Global packages stored in PNPM_HOME will be added to PATH by pnpm itself
export PNPM_HOME="$HOME/Library/pnpm"

## Dart CLI completion (conditional load)
[[ -f $HOME/.dart-cli-completion/zsh-config.zsh ]] && . $HOME/.dart-cli-completion/zsh-config.zsh

# Additional PATH entries
export PATH="$HOME/.shorebird/bin:$PATH"
export SOURCE_DATE_EPOCH="0"
export PATH="$PATH:$HOME/.pub-cache/bin"

# Bun completions (conditional load)
[[ -s "$HOME/.oh-my-zsh/completions/_bun" ]] && source "$HOME/.oh-my-zsh/completions/_bun"

# Mise (lazy load for better performance)
if command -v mise &> /dev/null; then
  eval "$(~/.local/bin/mise activate zsh)"
fi

# Yazelix configuration
[[ -f "$HOME/.config/yazelix/zsh/yazelix_zsh_config.zsh" ]] && source "$HOME/.config/yazelix/zsh/yazelix_zsh_config.zsh"

# Yazelix aliases
alias yazelix="$HOME/.config/yazelix/bash/launch-yazelix.sh"
alias yzx="$HOME/.config/yazelix/bash/launch-yazelix.sh"
alias zjn="$HOME/.config/yazelix/bash/zellij-nix.sh"

# Starship prompt (loaded last for best performance)
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# Add local scripts to the path (placed last to ensure precedence over cargo and other bins)
PATH="$HOME/.local/bin:$PATH"

# Profiling output (uncomment the zmodload at the top to enable)
# zprof
