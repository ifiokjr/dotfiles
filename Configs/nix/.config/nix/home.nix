{
  pkgs,
  lib,
  lite ? false,
  ifiokjr-nixpkgs,
  ...
}:

let
  extra = ifiokjr-nixpkgs.packages.${pkgs.stdenv.system};
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
      bun
      cargo-sweep
      cargo-update
      cloudflared
      extra.cursor-cli
      deno
      devenv
      direnv
      dotnet-sdk
      dprint
      emscripten
      evcxr
      fluxcd
      gh
      git
      git-filter-repo
      git-lfs
      go
      graphite-cli
      jdk17
      kubernetes-helm
      lazygit
      lld
      llvm
      maestro
      mise
      neovim
      nixd
      nixfmt
      ollama
      opencode
      pulumi-bin
      pulumi-esc
      extra.knope
      extra.mdt
      extra.racket-minimal
      rustup
      spec-kit

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
      nufmt
      serpl
      shellcheck
      shfmt
      taplo
      yamllint

      # Language Servers & Tools
      kotlin
      ktlint
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
      cirrus-cli
      coreutils
      curl
      diffutils
      double-conversion
      dust
      gnumake
      gzip
      nix-prefetch
      nixpkgs-review
      openssh
      openssl
      orchard
      podman
      protobuf
      scooter
      sshpass
      sqld
      tealdeer
      tuckr
      uv
      vncdo
      zlib

      # Custom packages from ifiokjr/nixpkgs
      extra.cargo-interactive-update
      extra.pnpm-standalone

      # Fonts
      google-fonts # Includes Duru Sans, Kranky, Rubik, Short Stack, etc.
      inconsolata
      recursive
      roboto
      extra.agave
      nerd-fonts.caskaydia-cove
      nerd-fonts.code-new-roman
      nerd-fonts.droid-sans-mono
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.hack
      nerd-fonts.mononoki
      nerd-fonts.noto
      nerd-fonts.profont
      nerd-fonts.sauce-code-pro
      nerd-fonts.symbols-only
    ]
    ++ lib.optionals (!lite) [
      google-chrome
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin (
      [
        # macOS-only packages
        _1password-cli
        cocoapods
        fvm # Flutter Version Management (macOS/Windows only)
        mas
        pinentry_mac
        powershell
        swiftformat
        swiftlint
      ]
      ++ lib.optionals (!lite) [
        code-cursor
      ]
    )
    ++ lib.optionals pkgs.stdenv.isLinux (
      # Linux-only packages (macOS equivalents are in darwin.nix systemPackages)
      lib.optionals (!lite) [
        blender # broken on macOS in nixpkgs; macOS uses nix-casks
        ghostty
        ungoogled-chromium
      ]
    );

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

  # Activation scripts
  home.activation.installRacketPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${extra.racket-minimal}/bin/raco pkg install --skip-installed --auto --scope user fmt || true
  '';

  # Keep pnpm global packages in sync from the managed manifest when available.
  # This is best-effort to avoid making activation fail when pnpm is unavailable.
  home.activation.syncPnpmGlobalPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "$HOME/.local/bin/pnpm:global:sync" ]; then
      "$HOME/.local/bin/pnpm:global:sync" --quiet --no-fail || true
    fi
  '';

  # Environment variables
  home.sessionVariables = {
    EDITOR = "hx";
  };

  programs = {
    home-manager.enable = true;
  };
}
