# You may need to manually set your language environment
export LANG="en_GB.UTF-8"
export LC_CTYPE="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"
export GPG_TTY=$(tty)

# Preferred editor for local and remote sessions
export EDITOR='nano'

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Updated Path Exports
export PATH="/usr/local/sbin:$PATH"

# Export NVM Installation
export NVM_DIR="$HOME/.nvm"

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Auto Suggest Command
_zsh_autosuggest_strategy_histdb_top_here() {
    local query="select commands.argv from
history left join commands on history.command_id = commands.rowid
left join places on history.place_id = places.rowid
where places.dir LIKE '$(sql_escape $PWD)%'
and commands.argv LIKE '$(sql_escape $1)%'
group by commands.argv order by count(*) desc limit 1"
    suggestion=$(_histdb_query "$query")
}

# Defines Auto Suggestion Strategy
ZSH_AUTOSUGGEST_STRATEGY=histdb_top_here

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(
	git
	cp
	colorize
	node
	npm
	wd
	thefuck
	man
	colored-man-pages
	quotes
)

if [[ $OSTYPE == darwin* ]]; then
  plugins+=(iterm2 macports osx)
	export EDITOR="code"

	# Timely Tracking
	PROMPT_TITLE='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/~}\007"'
	export PROMPT_COMMAND="${PROMPT_COMMAND} ${PROMPT_TITLE}; "

	# Set up showing files
	# http://ianlunn.co.uk/articles/quickly-showhide-hidden-files-mac-os-x-mavericks/
	alias showFiles='defaults write com.apple.finder AppleShowAllFiles YES; killall Finder /System/Library/CoreServices/Finder.app'
	alias hideFiles='defaults write com.apple.finder AppleShowAllFiles NO; killall Finder /System/Library/CoreServices/Finder.app'

	# Example aliases
	alias zshconfig="code ~/.zshrc"
	alias ohmyzsh="code ~/.oh-my-zsh"

	# Android SDK
	export ANDROID_SDK_ROOT=/usr/local/share/android-sdk
	export ANDROID_SDK=/usr/local/share/android-sdk
	export ANDROID_HOME=/usr/local/share/android-sdk
	export ANDROID_NDK_HOME="/usr/local/share/android-ndk"
	export ANDROID_NDK="/usr/local/share/android-ndk"
	export PATH="$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/tools:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/tools/bin:$PATH"
fi

# Loads Homebrew (only if exists and needed (Linux))
[[ ! -f /home/linuxbrew/.linuxbrew/bin/brew ]] || eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

# Loads NVM
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$(brew --prefix)/opt/nvm/nvm.sh"

# Loads NVM Completion
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && . "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"

# Loads NVM
nvm use > /dev/null 2>&1

# Loads The-Fuck
eval $(thefuck --alias f)

# Load GitHub CLI Completion
eval "$(gh completion -s zsh)"

if [[ $OSTYPE == darwin* ]]; then
	# Helps on macOS for Autocompletion
	HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
fi

# Loads SQLite History
source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-histdb/sqlite-history.zsh"
source "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-histdb/histdb-interactive.zsh"
autoload -Uz add-zsh-hook

# Custom Aliases
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
alias gpfnv="gpf --no-verify"
alias gpnv="gp --no-verify"

# only macOS supports casks
[[ -f /home/linuxbrew/.linuxbrew/bin/brew ]] || alias bu="brew upgrade && brew cask upgrade"

# Load Oh My ZSH
source $ZSH/oh-my-zsh.sh

# export MANPATH="/usr/local/man:$MANPATH"

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


## Utils

findconfig() {
    # from: https://www.npmjs.com/package/find-config#algorithm
    # 1. If X/file.ext exists and is a regular file, return it. STOP
    # 2. If X has a parent directory, change X to parent. GO TO 1
    # 3. Return NULL.

    if [ -f "$1" ]; then
        printf '%s\n' "${PWD%/}/$1"
        elif [ "$PWD" = / ]; then
        false
    else
        # a subshell so that we don't affect the caller's $PWD
        (cd .. && findconfig "$1")
    fi
}

## Git add pattern.
gaw() {
    git add ./\*"$1"
}