# config.nu - Nushell configuration
# Loaded after env.nu. Contains shell settings, aliases, and commands.
# Shell configuration
$env.config = {
    show_banner: false
    completions: {
        case_sensitive: false
        quick: true
        partial: true
        algorithm: "fuzzy"
    }
    history: {
        max_size: 100_000
        sync_on_enter: true
        file_format: "sqlite"
        isolation: false
    }
    table: {mode: rounded}
    cursor_shape: {emacs: line, vi_insert: line, vi_normal: block}
    hooks: {
        pre_prompt: [
            {||
                # Direnv integration - loads/unloads environment variables based
                # on .envrc files. Runs before every prompt (like zsh precmd) so
                # it catches: directory changes, `direnv allow`, and file edits.
                # Based on: https://direnv.net/docs/hook.html
                if (which direnv | is-empty) { return }
                # Capture stdout/stderr so direnv/devenv build errors don't corrupt prompt rendering.
                # (e.g. "↑↓ navigatedirenv: failed to build the devenv environment")
                let result = (^direnv export json | complete)
                if ($result.exit_code != 0) {
                    if ($env | get -o DOTFILES_DEBUG | is-not-empty) {
                        let err = ($result.stderr | str trim)
                        if ($err | is-not-empty) { print $"(ansi yellow)direnv skipped:(ansi reset) ($err)" }
                    }
                    return
                }
                let stdout = ($result.stdout | str trim)
                if ($stdout | is-empty) { return }
                let direnv_out = (try {
                    $stdout | from json
                } catch { {} })
                if ($direnv_out | is-empty) { return }
                let env_to_load = if ($direnv_out | get -o PATH | is-not-empty) {
                    let path_as_list = ($direnv_out | get PATH | split row (char esep))
                    $direnv_out | merge { PATH: $path_as_list }
                } else { $direnv_out }
                $env_to_load | load-env
            }
        ]
        env_change: {
            PWD: [
                {||
                    # Directory stack — push current directory, deduplicate, cap at 10.
                    # Mirrors zsh auto_pushd behaviour used by oh-my-zsh's `d` command.
                    let dir = ($env.PWD | path expand)
                    $env.DIRSTACK = ([$dir] | append ($env.DIRSTACK | where { $in != $dir }) | first 10)
                }
            ]
        }
    }
}
# Devenv hook is sourced from cache (created in env.nu to ensure the file
# exists at parse time). See env.nu for caching/mtime logic.
source ~/.cache/devenv/hook.nu
# Auto-activate Node.js from pnpm-workspace.yaml useNodeVersion (pnpm-standalone)
def --env pnpm_auto_activate [] {
    let debug = ($env | get -o DOTFILES_DEBUG | is-not-empty)
    if (which pnpm-activate-env | is-empty) {
        if $debug { print "(ansi yellow)pnpm_auto_activate skipped: pnpm-activate-env not found(ansi reset)" }
        return
    }
    let res = (^pnpm-activate-env | complete)
    if $res.exit_code != 0 {
        if $debug { print "(ansi yellow)pnpm_auto_activate skipped: pnpm-activate-env failed(ansi reset)" }
        return
    }
    let output_lines = ($res.stdout | str trim | lines)
    if ($output_lines | is-empty) {
        if $debug { print "(ansi yellow)pnpm_auto_activate skipped: pnpm-activate-env returned no output lines(ansi reset)" }
        return
    }
    let first = ($output_lines | first)
    if $first == "" {
        if $debug { print "(ansi yellow)pnpm_auto_activate skipped: pnpm-activate-env returned no output lines(ansi reset)" }
        return
    }
    let parsed = (try {
        $first | parse "__pnpm_activate_node_bin='{bin}'"
    } catch { [] })
    if ($parsed | is-empty) {
        if $debug { print "(ansi yellow)pnpm_auto_activate skipped: pnpm-activate-env output did not include node bin(ansi reset)" }
        return
    }
    let node_bin = ($parsed | get -o 0.bin)
    if $node_bin == "" {
        if $debug { print "(ansi yellow)pnpm_auto_activate skipped: parsed node bin was empty(ansi reset)" }
        return
    }
    if ($env.PATH | any { |p| $p == $node_bin }) == false { $env.PATH = ($env.PATH | prepend $node_bin) }
}
$env.config.hooks.env_change.PWD = (($env.config.hooks.env_change | get -o PWD | default []) | append { |before, after| pnpm_auto_activate })
pnpm_auto_activate
# Secrets
use modules/secrets.nu ss
# General aliases
# Reload shell
alias s = exec nu
# Job control
alias fg = job unfreeze
# Nix
alias update = nix flake update --flake $"($env.HOME)/.config/nix"
# Editors
alias vim = nvim
alias n = nvim
# Tools
alias zj = zellij
alias lg = lazygit
alias cl = clear
alias pinentry = pinentry-mac
alias cc = claude --dangerously-skip-permissions
alias co = codex --dangerously-bypass-approvals-and-sandbox
alias oc = opencode
alias g = git
alias md = mkdir
alias rd = rmdir
# Config editing
alias nushellconfig = hx $"($nu.default-config-dir)/config.nu"
# Rust / Cargo
alias cr = cargo run
alias cb = cargo build
alias ct = cargo test
alias cch = cargo check
alias ccl = cargo clippy
alias cf = cargo fmt
alias cw = cargo watch -x run
# pnpm
alias p = pnpm
alias pu = pnpm update -g -iL
# alias pi = pnpm install
# alias pd = pnpm dev
# alias pb = pnpm build
# alias pt = pnpm test
# alias px = pnpm exec
# alias pa = pnpm add
# alias pad = pnpm add -D
# alias pr = pnpm run
# Docker / Compose
alias dk = docker
alias dkc = docker compose
alias dkcu = docker compose up -d
alias dkcd = docker compose down
alias dkcl = docker compose logs -f
alias dkce = docker compose exec
alias dkps = docker ps
# Nix / Devenv
alias nr = rebuild
alias nfc = nix flake check --flake ~/.config/nix
alias nfu = nix flake update --flake ~/.config/nix
alias ns = nix search nixpkgs
alias de = devenv up
# File listing (lsd)
alias l = lsd -lah
alias la = lsd -lAh
alias ll = lsd -lh
alias lls = lsd -G
alias lsa = lsd -lah
# Git helper commands
def git_main_branch [] {
    let branches = (
        ^git branch --list main master | lines | each { str trim } | where { $in != "" }
    )
    if ("main" in $branches) { "main" } else if ("master" in $branches) { "master" } else { "main" }
}
def git_develop_branch [] {
    let branches = (
        ^git branch --list dev develop development | lines | each { str trim } | where { $in != "" }
    )
    if ("develop" in $branches) { "develop" } else if ("dev" in $branches) { "dev" } else if ("development" in $branches) { "development" } else { "develop" }
}
def git_current_branch [] {
    ^git branch --show-current | str trim
}
# Git aliases
# add
alias ga = git add
alias gaa = git add --all
alias gapa = git add --patch
alias gau = git add --update
alias gav = git add --verbose
# am / apply
alias gam = git am
alias gama = git am --abort
alias gamc = git am --continue
alias gams = git am --skip
alias gamscp = git am --show-current-patch
alias gap = git apply
alias gapt = git apply --3way
# branch
alias gb = git branch
alias gba = git branch --all
alias gbd = git branch --delete
alias gbD = git branch --delete --force
alias gbl = git blame -w
alias gbm = git branch --move
alias gbnm = git branch --no-merged
alias gbr = git branch --remote
# bisect
alias gbs = git bisect
alias gbsb = git bisect bad
alias gbsg = git bisect good
alias gbsn = git bisect new
alias gbso = git bisect old
alias gbsr = git bisect reset
alias gbss = git bisect start
# checkout
alias gco = git checkout
alias gco1 = git checkout -
alias gco2 = git checkout @{-2}
alias gco3 = git checkout @{-3}
alias gco4 = git checkout @{-4}
alias gco5 = git checkout @{-5}
alias gcb = git checkout -b
alias gcB = git checkout -B
alias gcor = git checkout --recurse-submodules
# commit
alias gc = git commit --verbose
alias "gc!" = git commit --verbose --amend
alias gca = git commit --verbose --all
alias "gca!" = git commit --verbose --all --amend
alias gcam = git commit --all --message
alias "gcan!" = git commit --verbose --all --no-edit --amend
alias "gcann!" = git commit --verbose --all --date=now --no-edit --amend
alias "gcans!" = git commit --verbose --all --signoff --no-edit --amend
alias gcas = git commit --all --signoff
alias gcasm = git commit --all --signoff --message
alias gcmsg = git commit --message
alias gcn = git commit --verbose --no-edit
alias "gcn!" = git commit --verbose --no-edit --amend
alias gcs = git commit --gpg-sign
alias gcsm = git commit --signoff --message
alias gcss = git commit --gpg-sign --signoff
alias gcssm = git commit --gpg-sign --signoff --message
alias gcfu = git commit --fixup
# cherry-pick
alias gcp = git cherry-pick
alias gcpa = git cherry-pick --abort
alias gcpc = git cherry-pick --continue
# clone
alias gcl = git clone --recurse-submodules
alias gclf = git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules
# config
alias gcf = git config --list
alias gcount = git shortlog --summary --numbered
# diff
alias gd = git diff
alias gdca = git diff --cached
alias gdcw = git diff --cached --word-diff
alias gds = git diff --staged
alias gdup = git diff "@{upstream}"
alias gdw = git diff --word-diff
# fetch
alias gf = git fetch
alias gfa = git fetch --all --tags --prune --jobs=10
alias gfo = git fetch origin
# help / clean
alias ghh = git help
alias gclean = git clean --interactive -d
# log
alias gl = git pull
alias glg = git log --stat
alias glgg = git log --graph
alias glgga = git log --graph --decorate --all
alias glgm = git log --graph --max-count=10
alias glgp = git log --stat --patch
alias glo = git log --oneline --decorate
alias glog = git log --oneline --decorate --graph
alias gloga = git log --oneline --decorate --graph --all
alias glol = git log --graph --pretty "%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"
alias glola = git log --graph --pretty "%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all
alias glols = git log --graph --pretty "%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat
alias glod = git log --graph --pretty "%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"
alias glods = git log --graph --pretty "%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short
# merge
alias gm = git merge
alias gma = git merge --abort
alias gmc = git merge --continue
alias gmff = git merge --ff-only
alias gms = git merge --squash
alias gmtl = git mergetool --no-prompt
# push
alias gp = git push
alias gpd = git push --dry-run
alias gpf = git push --force-with-lease --force-if-includes
alias gp! = git push --force-with-lease --force-if-includes
alias gpnv = git push --no-verify
alias "gpnv!" = git push --force-with-lease --force-if-includes --no-verify
alias gpfnv = git push --force-with-lease --force-if-includes --no-verify
alias gpu = git push upstream
alias gpv = git push --verbose
# pull / rebase
alias gpr = git pull --rebase
alias gpra = git pull --rebase --autostash
alias gprav = git pull --rebase --autostash -v
alias gprv = git pull --rebase -v
alias grb = git rebase
alias grba = git rebase --abort
alias grbc = git rebase --continue
alias grbi = git rebase --interactive
alias grbo = git rebase --onto
alias grbs = git rebase --skip
# remote
alias gr = git remote
alias gra = git remote add
alias grmv = git remote rename
alias grrm = git remote remove
alias grset = git remote set-url
alias grup = git remote update
alias grv = git remote --verbose
# reset / restore
alias grH = git reset "HEAD^"
alias grev = git revert
alias greva = git revert --abort
alias grevc = git revert --continue
alias grf = git reflog
alias grh = git reset
alias grhh = git reset --hard
alias grhk = git reset --keep
alias grhs = git reset --soft
alias grs = git restore
alias grss = git restore --source
alias grst = git restore --staged
alias gru = git reset --
alias grm = git rm
alias grmc = git rm --cached
# show / status
alias gsb = git status --short --branch
alias gsh = git show
alias gsps = git show --pretty=short --show-signature
alias gss = git status --short
alias gst = git status
# stash
alias gsta = git stash push
alias gstaa = git stash apply
alias gstall = git stash --all
alias gstc = git stash clear
alias gstd = git stash drop
alias gstl = git stash list
alias gstp = git stash pop
alias gsts = git stash show --patch
alias gstu = git stash push --include-untracked
# submodule
alias gsi = git submodule init
alias gsu = git submodule update
# switch
alias gsw = git switch
alias gswc = git switch --create
# tag
alias gta = git tag --annotate
alias gts = git tag --sign
# ignore
alias gignore = git update-index --assume-unchanged
alias gunignore = git update-index --no-assume-unchanged
# worktree
alias gw = git worktree
alias gwa = git worktree add
alias gwch = git log --patch --abbrev-commit --pretty=medium --raw
alias gwh = git worktree --help
alias gwl = git worktree list --porcelain
alias gwm = git worktree move
alias gwr = git worktree remove
# Dynamic git commands (branch-aware)
def gcm [] { ^git checkout (git_main_branch) }
def gcd [] { ^git checkout (git_develop_branch) }
def ggpull [] { ^git pull origin (git_current_branch) }
def ggpush [] { ^git push origin (git_current_branch) }
def ggsup [] { ^git branch $"--set-upstream-to=origin/(git_current_branch)" }
def gluc [] { ^git pull upstream (git_current_branch) }
def glum [] { ^git pull upstream (git_main_branch) }
def gmom [] { ^git merge $"origin/(git_main_branch)" }
def gmum [] { ^git merge $"upstream/(git_main_branch)" }
def gprom [...rest] { ^git pull --rebase origin (git_main_branch) ...$rest }
def gpromi [] { ^git pull --rebase=interactive origin (git_main_branch) }
def gprum [...rest] { ^git pull --rebase upstream (git_main_branch) ...$rest }
def gprumi [] { ^git pull --rebase=interactive upstream (git_main_branch) }
def gpsup [] { ^git push --set-upstream origin (git_current_branch) }
def gpsupf [] { ^git push --set-upstream origin (git_current_branch) --force-with-lease --force-if-includes }
def grbd [] { ^git rebase (git_develop_branch) }
def grbm [] { ^git rebase (git_main_branch) }
def grbom [] { ^git rebase $"origin/(git_main_branch)" }
def grbum [] { ^git rebase $"upstream/(git_main_branch)" }
def groh [] { ^git reset $"origin/(git_current_branch)" --hard }
def gswd [] { ^git switch (git_develop_branch) }
def gswm [] { ^git switch (git_main_branch) }
def gpod [branch: string] { ^git push origin --delete $branch }
# cd to git repository root
def --env grt [] { cd (^git rev-parse --show-toplevel | str trim) }
# git tag version sorted
def gtv [] {
    ^git tag | lines | sort --natural | reverse
}
# git describe latest tag
def gdct [] { ^git describe --tags (^git rev-list --tags --max-count=1 | str trim) }
# git diff-tree (show changed files in a commit)
def gdt [commit: string] { ^git diff-tree --no-commit-id --name-only -r $commit }
# Complex git commands
# Push all branches and tags to origin
def gpoat [] {
    ^git push origin --all
    ^git push origin --tags
}
# WIP commit (work in progress)
def gwip [] {
    ^git add -A
    ^git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"
}
# Undo WIP commit
def gunwip [] {
    let msg = (^git log -1 --format="%s" | str trim)
    if ($msg | str starts-with "--wip--") { ^git reset HEAD~1 } else { print "No WIP commit found" }
}
# Pristine - reset to clean state
def gpristine [] {
    ^git reset --hard
    ^git clean --force -dfx
}
# List files ignored by git assume-unchanged
def gignored [] {
    ^git ls-files -v | lines | where { str starts-with "h" }
}
# Git squash all commits into one
def gsqa [message: string] {
    let tree_hash = (^git commit-tree $"HEAD^{tree}" -m $message | str trim)
    ^git reset $tree_hash
}
# Custom commands
# Open in Cursor
def c [...paths: string] {
    if ($paths | is-empty) { ^open -a "Cursor" . } else {
        $paths | each { |p| ^open -a "Cursor" $p }
    }
}
# Directory history (like oh-my-zsh 'd' command)
# Uses a session directory stack maintained by a PWD change hook.
# `d` shows recent directories numbered 0-9 (0 is current directory).
# `d <n>` jumps to directory at that index.
def --env d [index?: int] {
    let dirs = $env.DIRSTACK
    if ($index != null) {
        if $index >= 0 and $index < ($dirs | length) { cd ($dirs | get $index) } else { print $"(ansi red)Invalid index:(ansi reset) ($index) \(0-($dirs | length | $in - 1)\)" }
        return
    }
    $dirs | enumerate | each { |r|
        let display = ($r.item | str replace $env.HOME "~")
        print $"(ansi cyan)($r.index)(ansi reset)\t($display)"
    }
    null
}
# Startup time (only shown when DOTFILES_DEBUG is set)
if ($env | get -o DOTFILES_DEBUG | is-not-empty) {
    let elapsed = ((date now) - $env._SHELL_START)
    print $"(ansi blue)→(ansi reset) Shell loaded in ($elapsed | format duration ms)"
}
