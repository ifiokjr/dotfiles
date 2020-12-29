# dotfiles

## Explanation

A repo containing the setup scripts for my dotfile configuration. GitHub automatically looks at the user profile for a dotfiles repo and uses it to setup

## Get started

Clone this repo.

```bash
git clone https://github.com/ifiokjr/dotfiles
cd dotfiles
```

Run the installation command.

```bash
./install.sh
```

## Tools

### Homebrew

Manages installation on mac and linux. Casks are not supported on linux so there are two seperate bundle files `.Brewfile` (linux only) and `.Brewfile.mac`.

At the moment windows is not supported since I don't use a windows machine. If this changes I can update the script in the future.

### Asdf

Manage the versions of different packages. This is similar to `nvm` and `rvm` but it support version managers for multiple languages and libraries.

### oh-my-zsh

ZSH is used and `oh-my-zsh` is the underlying platform.

### powerlevel10k

Provides the theme for `oh-my-zsh`. This can be reconfigured via `p10k configure`.

## Special Thanks

This project was initially forked from https://github.com/ovflowd/dotfiles. Please star the repo to show your support.