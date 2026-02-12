{
  pkgs,
  lib,
  ...
}:

let
  # Custom packages
  pnpm-standalone = pkgs.callPackage ./packages/pnpm-standalone.nix { };
in
{
  # Home Manager configuration for nix-darwin integration
  #
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.11"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment. These packages are available to your user account.
  home.packages =
    with pkgs;
    [
      # Development Tools
      ast-grep
      atuin
      awscli2
      bat
      biome
      cargo-sweep
      cargo-update
      claude-code
      code-cursor
      cursor-cli
      cloudflared
      deno
      devenv
      direnv
      dprint
      emscripten
      evcxr
      gemini-cli
      gh
      git
      git-filter-repo
      git-lfs
      go
      graphite-cli
      jdk17
      lazygit
      maestro
      mise
      neovim
      nixd
      nixfmt
      opencode
      rustup

      # Shell & Terminal
      bashInteractive
      carapace
      fish
      nushell
      starship
      zellij
      zoxide

      # File Management
      exiftool
      fd
      fuc
      lsd
      ouch
      p7zip
      ripgrep
      rnr
      yazi

      # Text Processing
      jq
      kdlfmt
      serpl
      shfmt
      taplo

      # Language Servers & Tools
      kotlin
      kotlin-language-server
      lua-language-server
      markdown-oxide
      ruby
      ruby-lsp
      sqls
      tailwindcss-language-server
      yaml-language-server

      # Media & Graphics
      ffmpeg
      imagemagick
      poppler
      vhs

      # System Utilities
      act
      bottom
      cachix
      coreutils
      curl
      diffutils
      dust
      gnumake
      gzip
      nix-prefetch
      openssh
      openssl
      protobuf
      scooter
      sqld
      tealdeer
      tuckr
      uv
      zlib

      # Custom packages
      pnpm-standalone

      # Fonts
      nerd-fonts.fira-code
      nerd-fonts.symbols-only
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      # macOS-only packages
      cocoapods
      fvm # Flutter Version Management (macOS/Windows only)
    ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Environment variables
  home.sessionVariables = {
    EDITOR = "hx";
  };

  programs = {
    home-manager.enable = true;
  };
}
