# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Fix for rust builds
export MACOSX_DEPLOYMENT_TARGET="12.0"

# Make Yazelix’s Yazi config your default (it’s plugin-enhanced and adjusts layout based on width)
export YAZI_CONFIG_HOME="$HOME/.config/yazelix/yazi"

# Load secrets
__SECRETS_ENV="$HOME/.env.dotfiles"
[ -f $__SECRETS_ENV ] && set -a &&  source $__SECRETS_ENV && set +a

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

plugins=(
  git
  cp
  colorize
  node
  npm
  wd
  man
  colored-man-pages
  macos
  1password
  aliases
)

source $ZSH/oh-my-zsh.sh

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

# llvm
export LDFLAGS="-L$(brew --prefix llvm)/lib"
export LIBCLANG_PATH="$(brew --prefix llvm)/lib"
export LLVM_CONFIG_PATH="$(brew --prefix llvm)/bin/llvm-config"
export CPPFLAGS="-I$(brew --prefix llvm)/include"
export PATH="$(brew --prefix llvm)/bin:$PATH"

# To make helix the default sudo editor when run with `sudoedit` 
export SUDO_EDITOR=$(which hx)
# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='hx'
else
  export EDITOR='hx'
fi

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
alias s="source $HOME/.zshrc"
alias update="sudo zsh -c \"nix flake update --flake \$HOME/.config/nix\""
alias rebuild="sudo zsh -c \"darwin-rebuild switch --flake \$HOME/.config/nix#\$(whoami)\""
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

PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

# Timely Tracking
PROMPT_TITLE='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/~}\007"'
export PROMPT_COMMAND="${PROMPT_COMMAND} ${PROMPT_TITLE}; "

# direnv
export DIRENV_LOG_FORMAT=""
eval "$(direnv hook zsh)"

export GPG_TTY=$(tty)

 # Nix
 if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
 fi
 # End Nix

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

## [Completion]
## Completion scripts setup. Remove the following line to uninstall
[[ -f $HOME/.dart-cli-completion/zsh-config.zsh ]] && . $HOME/.dart-cli-completion/zsh-config.zsh || true
## [/Completion]

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"

export PATH="$HOME/.shorebird/bin:$PATH"
export SOURCE_DATE_EPOCH="0"
export PATH="$PATH:$HOME/.pub-cache/bin"

# bun completions
[ -s "$HOME/.oh-my-zsh/completions/_bun" ] && source "$HOME/.oh-my-zsh/completions/_bun"
eval "$(~/.local/bin/mise activate zsh)"

# Source Yazelix Zsh configuration (added by Yazelix)
source "$HOME/.config/yazelix/zsh/yazelix_zsh_config.zsh"
# BEGIN YAZELIX ALIASES (added by Yazelix)
alias yazelix="$HOME/.config/yazelix/bash/launch-yazelix.sh"
alias yzx="$HOME/.config/yazelix/bash/launch-yazelix.sh"
alias zjn="$HOME/.config/yazelix/bash/zellij-nix.sh"
# END YAZELIX ALIASES (added by Yazelix)

eval "$(starship init zsh)"

# Add local scripts to the path (placed last to ensure precedence over cargo and other bins)
PATH="$HOME/.local/bin:$PATH"
