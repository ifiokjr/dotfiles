#!/usr/bin/env zsh

## Installation script for dotfiles for use in github codespaces.

echo "\e[33m\n\n!! WARNING: This script will overwrite existing ZSH, Bash Profile and Oh-My-ZSH configurations !! \n"
echo "!! WARNING: Please do not open other terminal session until the scripts finishes !! \e[39m\n"

case "$(uname -s)" in
  Darwin)
    echo "\e[32m[DOT]\e[33m Darwin based environment detected ... \e[39m\n"
  ;;
  Linux)
    if [ "$(grep -Ei 'debian|buntu|mint' /etc/*release)" ]; then
      echo "\e[32m[DOT]\e[33m Debian based environment detected ... \e[39m\n"
      # install required dependencies
      echo "\e[32m[DOT]\e[34m installing packages ... \e[39m\n"
      sudo apt -y install build-essential git debconf locales > /dev/null 2>&1
      # generate utf-8 environment
      echo "\e[32m[DOT]\e[34m generating locales ... \e[39m\n"
      sudo locale-gen --purge en_GB.UTF-8 > /dev/null 2>&1
    # check if environment is fedora/redhat
    elif [ "$(grep -Ei 'fedora|redhat|centos' /etc/*release)" ]; then
      echo "\e[32m[DOT]\e[33m RedHat based environment detected ... \e[39m\n"
      # install required dependencies
      echo "\e[32m[DOT]\e[34m installing packages ... \e[39m\n"
      sudo dnf install @development-tools git -y > /dev/null 2>&1
      # generate utf-8 environment
      echo "\e[32m[DOT]\e[34m generating locales ... \e[39m\n"
      localedef -v -c -i en_GB -f UTF-8 en_GB.UTF-8 > /dev/null 2>&1
    fi
  ;;
  CYGWIN*|MINGW32*|MSYS*|MINGW*)
    echo "\e[32m[DOT]\e[33m Windows based environment detected ... \e[39m\n"
    echo "\e[32m[DOT]\e[31m This is not a supported environment. Exiting. \e[39m\n"
    exit 1
    ;;
  *)
    echo "\e[32m[DOT]\e[31m Unable to detected the environment! \e[39m\n"
    echo "\e[32m[DOT]\e[31m This is not a supported environment. Exiting. \e[39m\n"
    exit 1
  ;;
esac

# exports the language definitions
echo "\e[32m[DOT]\e[34m exporting locales ... \e[39m\n"
export LANG="en_GB.UTF-8"
export LC_CTYPE="en_GB.UTF-8"
export LC_ALL="en_GB.UTF-8"

# tells homebrew to do a silent install
export CI=1

# delete previous installations
echo "\e[32m[DOT]\e[34m deleting previous installation of this dotfiles ... \e[39m\n"
rm -rf $HOME/.oh-my-zsh/ $HOME/.zshrc $HOME/.bash_profile $HOME/.p10k.zsh > /dev/null 2>&1

# copies base bash profile
echo "\e[32m[DOT]\e[34m copying bash profile file ... \e[39m\n"
cp -rf .bash_profile $HOME/.bash_profile > /dev/null 2>&1

# install the homebrew (if stdin is available requires confirmation)
echo "\e[32m[DOT]\e[34m installing homebrew ...  \e[39m\n"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" > /dev/null 2>&1

# Copy brewfiles
echo "\e[32m[DOT]\e[34m copying brew files ... \e[39m\n"
cp -rf Brewfile $HOME/.Brewfile > /dev/null 2>&1

if [[ $OSTYPE == darwin* ]]; then
  cp -rf Brewfile.mac $HOME/.Brewfile.mac > /dev/null 2>&1
fi

case "$(uname -s)" in
  Darwin)
  ;;
  Linux)
    echo "\e[32m[DOT]\e[34m configuring homebrew ... \e[39m\n"
    # installs homebrew on the environment
    echo "eval \$($(brew --prefix)/bin/brew shellenv)" >> $HOME/.profile

    # enables homebrew on current runtime
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)

    echo "\e[32m[DOT]\e[34m installing nerd fonts ... \e[39m\n"
    # creates local fonts directory
    mkdir -p $HOME/.local/share/fonts

    (
      # goes to the directory
      cd $HOME/.local/share/fonts

      # downloads the font file
      curl -fLo "Hack NF.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/Hack/Regular/complete/Hack%20Regular%20Nerd%20Font%20Complete%20Mono.ttf > /dev/null 2>&1

      # reloads font cache
      echo "\e[32m[DOT]\e[34m rebuilding fonts ... \e[39m\n"
      fc-cache -f -v > /dev/null 2>&1
    )
  ;;
  *)
  ;;
esac

if [ ! -d /usr/local/sbin ]; then
  mkdir /usr/local/sbin
  chmod 777 /usr/local/sbin
fi


echo "\e[32m[DOT]\e[34m installing general homebrew packages ... \e[39m\n"
brew bundle --file $HOME/.Brewfile

if [[ $OSTYPE == darwin* ]]; then
  echo "\e[32m[DOT]\e[34m installing macOS specific homebrew packages ... \e[39m\n"
  brew bundle --file $HOME/.Brewfile.mac

  echo "\e[32m[DOT]\e[34m launching background services ... \e[39m\n"
  brew services start postgresql > /dev/null 2>&1
  brew services start redis > /dev/null 2>&1

  git config --global core.editor "code --wait" > /dev/null 2>&1
  git config --global push.default current
  git config --global pager.branch false
  git config --global user.email "ifiokotung@gmail.com"
  git config --global user.name "Ifiok Jr."
  git config --global merge.tool "vscode"
  git config --global mergetool.vscode.cmd 'code --wait $MERGED'
  git config --global diff.tool default-difftool
  git config --global difftool.default-diftool.cmd 'code --wait --diff $LOCAL $REMOTE'
fi

# installs oh-my-zsh
echo "\e[32m[DOT]\e[34m installing oh my zsh ... \e[39m\n"
! sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended > /dev/null 2>&1

# copies the ZSH environment file
echo "\e[32m[DOT]\e[34m copy zsh file ... \e[39m\n"
cp -rf .zshrc $HOME/.zshrc > /dev/null 2>&1

# install asdf
echo "\e[32m[DOT]\e[34m install asdf ... \e[39m\n"
echo -e "\n\nsource $(brew --prefix asdf)/asdf.sh" >> $HOME/.zshrc

# auto install default python packages
cp -rf default-python-packages $HOME/.default-python-packages > /dev/null 2>&1

TOOL_VERSIONS=""
ASDF_PLUGINS=(
  flutter
  python
  pnpm
  kotlin
  dart
  golang
  rust
  deno
)

for plugin in $ASDF_PLUGINS
do
  echo "\e[32m[DOT]\e[34m install plugin: $plugin ... \e[39m\n"
  asdf plugin add $plugin
  asdf install $plugin latest
  version=`asdf latest $plugin`
  asdf global $plugin $version
  TOOL_VERSIONS="$plugin $version\n$TOOL_VERSIONS"
done

# setup node version
echo "\e[32m[DOT]\e[34m installing node 14 ... \e[39m\n"
asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring' > /dev/null 2>&1
asdf install nodejs latest:14
NODE_VERSION=$(asdf latest nodejs 14)
asdf global nodejs $NODE_VERSION
TOOL_VERSIONS="nodejs $NODE_VERSION\n$TOOL_VERSIONS"

# Add the rust binary tools
echo -e "source $HOME/.asdf/installs/rust/$(asdf latest rust)/env" >> $HOME/.zshrc

# install ruby gems
echo "\e[32m[DOT]\e[34m installing ruby bundler ... \e[39m\n"
brew gem install bundler --homebrew-ruby > /dev/null 2>&1
brew gem install solargraph --homebrew-ruby > /dev/null 2>&1
brew gem install fastlane --homebrew-ruby > /dev/null 2>&1

# creating default tool versions
echo -e $TOOL_VERSIONS > $HOME/.tool-versions

# configures git lfs
echo "\e[32m[DOT]\e[34m configuring git lfs ... \e[39m\n"
git lfs install --system > /dev/null 2>&1

# updates git configuration
echo "\e[32m[DOT]\e[34m enabling default git strategies ... \e[39m\n"
git config --global pull.rebase true

echo "\e[32m[DOT]\e[34m installing oh my zsh plugins ... \e[39m\n"

# installs power-level-10k
! git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" > /dev/null 2>&1

# installs zsh history db
! git clone https://github.com/larkery/zsh-histdb.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-histdb" > /dev/null 2>&1

echo "\e[32m[DOT]\e[34m copying environment files ... \e[39m\n"

# copies the PowerLevel10K configuration file
cp -rf .p10k.zsh $HOME/.p10k.zsh > /dev/null 2>&1

# add the zsh autocomplete and auto suggest scripts
echo -e "source $(brew --prefix zsh-autosuggestions)/share/zsh-autosuggestions/zsh-autosuggestions.zsh" >> $HOME/.zshrc
echo -e "source $(brew --prefix zsh-syntax-highlighting)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> $HOME/.zshrc

# loads the source
source $HOME/.zshrc

# Initializes history db
echo "\e[32m[DOT]\e[34m initializing history database ... \e[39m\n"
histdb-sync > /dev/null 2>&1

# Instructions on how to port old history into new history.
echo "\e[32m[DOT]\e[39m Port your history to \`\e[90mzsh-histdb\e[39m\`.\n\`\e[36mpnpx histdbimport\` \e[39m\n"

# Remove the last login prompt when opening a new terminal
touch $HOME/.hushlogin

# Copy the custom quotes plugin.
cp -rf quotes "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/quotes

# Cleanup uneccessary files.
echo "\e[32m[DOT]\e[34m cleanup unneeded files ... \e[39m\n"
rm -rf $HOME/.Brewfile $HOME/.Brewfile.mac $HOME/.default-python-packages > /dev/null 2>&1

echo "\e[32mInstallation Finished. Exiting. \e[39m\n"

exit 0
