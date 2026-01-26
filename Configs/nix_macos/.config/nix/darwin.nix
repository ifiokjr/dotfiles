{
  config,
  pkgs,
  self,
  username,
  ...
}:

{
  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  # User configuration
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };

  # Set primary user for darwin options that require it
  system.primaryUser = username;

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    brews = [
      "dotnet"
      "double-conversion"
      "flux"
      "lld"
      "llvm"
      "mas"
      "ollama"
      "pinentry-mac"
      "yamllint"
    ];
    casks = [
      "1password"
      "1password-cli"
      "alt-tab" # provides a saner UI/UX when switching tabs
      "android-ndk"
      "android-studio"
      "blender"
      "brave-browser"
      "charles"
      "cursor"
      "db-browser-for-sqlite"
      "dbeaver-community"
      "discord"
      "dotnet-sdk"
      "duet"
      "figma"
      "firefox"
      "flux-app"
      "font-agave-nerd-font"
      "font-caskaydia-cove-nerd-font"
      "font-code-new-roman-nerd-font"
      "font-droid-sans-mono-nerd-font"
      "font-duru-sans"
      "font-fira-code"
      "font-fira-code-nerd-font"
      "font-fira-mono-nerd-font"
      "font-hack-nerd-font"
      "font-inconsolata"
      "font-kranky"
      "font-mononoki-nerd-font"
      "font-noto-nerd-font"
      "font-profont-nerd-font"
      "font-recursive"
      "font-recursive-code"
      "font-roboto"
      "font-rubik"
      "font-sauce-code-pro-nerd-font"
      "font-short-stack"
      "font-symbols-only-nerd-font"
      "gdevelop"
      "geekbench"
      "ghostty"
      "godot"
      "google-chrome"
      "google-drive"
      "gpg-suite"
      "ledger-live"
      "microsoft-edge"
      "nordvpn"
      "obs"
      "ollama-app"
      "orbstack"
      "podman-desktop"
      "powershell"
      "qbittorrent"
      "racket"
      "react-native-debugger"
      "reactotron"
      "setapp"
      "slack"
      "steam"
      "telegram"
      "the-unarchiver"
      "visual-studio-code"
      "vlc"
      "vysor"
      "whatsapp"
      "zed"
      "zoom"
    ];
  };

  # System-level packages (only those that require system integration)
  # Most packages are now managed in home.nix
  environment.systemPackages = with pkgs; [
    # macOS-specific system utilities
    mkalias # For creating app aliases in /Applications

    # Core system libraries that other packages depend on
    apple-sdk_15
    libiconv
    fontconfig
    freetype
    jdk # Some system tools may need Java
  ];

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # system.activationScripts.applications.text =
  #   let
  #     env = pkgs.buildEnv {
  #       name = "system-applications";
  #       paths = config.environment.systemPackages;
  #       pathsToLink = "/Applications";
  #     };
  #   in
  #   pkgs.lib.mkForce ''
  #     # Set up applications.
  #     echo "setting up /Applications..." >&2
  #     rm -rf /Applications/Nix\ Apps
  #     mkdir -p /Applications/Nix\ Apps
  #     find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
  #     while IFS= read -r src; do
  #       app_name=$(basename "$src")
  #       echo "copying $src" >&2
  #       ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
  #     done
  #   '';

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
  # system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform is inherited from flake.nix darwinSystem configuration
  # No need to set nixpkgs.hostPlatform here as it's set at the flake level

  system.defaults = {
    dock.autohide = true;
  };
}
