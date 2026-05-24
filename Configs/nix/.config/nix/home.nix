{
  pkgs,
  lib,
  lite ? false,
  isDesktop ? false,
  alwaysOn ? false,
  ifiokjr-nixpkgs,
  ...
}:

let
  extraPackages = ifiokjr-nixpkgs.packages.${pkgs.stdenv.system};
  extra = extraPackages;
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
      cargo-clean-recursive
      cargo-sweep
      cargo-update
      cloudflared
      deno
      devenv
      direnv
      dprint
      fluxcd
      gh
      git
      git-filter-repo
      git-lfs
      graphite-cli
      jdk17
      kubernetes-helm
      lazygit
      lld
      llvm
      mise
      neovim
      nixd
      nixfmt
      extra.ollama
      opencode
      python3
      extra.knope
      extra.mdt
      rustup
      extra.secretspec

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
      shellcheck
      shfmt
      taplo
      yamllint

      # Language Servers & Tools
      kotlin
      ktlint
      bash-language-server
      kotlin-language-server
      lua-language-server
      markdown-oxide
      ruby
      ruby-lsp
      sqls
      tailwindcss-language-server
      typescript-language-server
      vscode-langservers-extracted
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
      gawk
      gnumake
      gzip
      hyperfine
      nh
      nix-prefetch
      nixpkgs-review
      openssh
      openssl
      orchard
      podman
      postgresql_17
      postgresql17Packages.pgvector
      protobuf
      scooter
      sshpass
      sqld
      tailscale
      tealdeer
      tuckr
      uv
      vncdo
      zlib

      # Custom packages from ifiokjr/nixpkgs
      extra.cargo-interactive-update
      extra.ironclaw
      extra.monochange
      extra.pnpm-11
      extra.op # 1password

      # Fonts
      fontforge
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
      nerd-fonts.profont
      nerd-fonts.sauce-code-pro
      nerd-fonts.symbols-only
    ]
    ++ lib.optionals (!lite) [
      # Heavy/optional packages skipped in lite mode (~8 GB saved)
      dotnet-sdk
      emscripten
      evcxr
      go
      google-fonts # 2.3 GB — 1800+ fonts
      maestro
      pulumi-bin # 4.4 GB — install on-demand for infra work
      pulumi-esc

      # Cross-platform packages from ifiokjr/nixpkgs
      extra.godot
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin (
      lib.optionals (!lite) [
        # macOS-only packages (heavy, skipped in lite mode)
        powershell
      ]
    )
    ++ lib.optionals pkgs.stdenv.isLinux (
      # Linux-only packages (macOS equivalents are in darwin.nix systemPackages)
      [
        gnome-keyring
      ]
      ++ lib.optionals (!lite) [
        blender # broken on macOS in nixpkgs; macOS uses Homebrew casks
        ghostty
        google-chrome
        ungoogled-chromium
      ]
    )
    ++ lib.optionals (isDesktop && lite && pkgs.stdenv.isDarwin) [
      # Docker compatibility layer via podman (for lite macOS desktops like Mac Mini)
      # Provides `docker` and `docker-compose` commands backed by podman
      (pkgs.writeShellScriptBin "docker" ''exec podman "$@"'')
      (pkgs.writeShellScriptBin "docker-compose" ''exec podman-compose "$@"'')
      pkgs.podman-compose
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

  # Print progress marker before home-manager writes all managed files.
  # The writeBoundary is the long silent phase where hundreds of symlinks
  # are created. This marker tells the user something is happening.
  home.activation.preWriteBoundary = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
    echo "==> Writing home-manager configuration..."
  '';

  # Keep pnpm global packages in sync from the managed manifest when available.
  # This is best-effort to avoid making activation fail when pnpm is unavailable.
  home.activation.syncPnpmGlobalPackages = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "==> Syncing pnpm global packages (home-manager activation)..."
    if [ -x "$HOME/.local/bin/pnpm:global:sync" ]; then
      "$HOME/.local/bin/pnpm:global:sync" --quiet --no-fail || true
    fi
  '';

  # Initialize podman VM for Docker compatibility on lite macOS desktops.
  # Idempotent: podman machine init fails silently if a machine already exists.
  home.activation.initPodmanMachine = lib.hm.dag.entryAfter [ "writeBoundary" ] (
    lib.optionalString (isDesktop && lite && pkgs.stdenv.isDarwin) ''
      echo "==> Initializing podman VM (lite macOS desktop)..."
      if command -v podman >/dev/null 2>&1; then
        ${pkgs.podman}/bin/podman machine init 2>/dev/null || true
      fi
    ''
  );

  # Environment variables
  home.sessionVariables = {
    EDITOR = "hx";
  };

  programs = {
    home-manager.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Tailscale systemd user service (Linux standalone home-manager)
  # ---------------------------------------------------------------------------
  # On macOS, nix-darwin handles tailscaled via services.tailscale.enable.
  # On Linux with standalone home-manager (not NixOS), we need a user-level
  # systemd service. On NixOS, use services.tailscale.enable in your
  # system config instead — this user service is only for non-NixOS Linux.
  systemd.user.services.tailscaled = lib.mkIf pkgs.stdenv.isLinux {
    Unit = {
      Description = "Tailscale node daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.tailscale}/bin/tailscaled --state ~/.local/state/tailscale/tailscaled.state --socket ~/.local/state/tailscale/tailscaled.sock";
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
