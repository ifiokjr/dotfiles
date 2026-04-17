{
  description = "System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    ifiokjr-nixpkgs = {
      url = "github:ifiokjr/nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # Declarative tap management
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      darwin,
      home-manager,
      nixpkgs,
      ifiokjr-nixpkgs,
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-bundle,
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forAllSystems =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f system;
          }) supportedSystems
        );

      # Helper function to create configurations for a specific user.
      # Darwin-specific package workarounds are applied as an overlay so every
      # consumer (including setup bootstrap and CI) benefits.
      darwinWorkaroundsOverlay =
        final: prev:
        prev.lib.optionalAttrs prev.stdenv.isDarwin {
          # Work around intermittent ast-grep check failures on Darwin
          # (`Illegal byte sequence (os error 92)`) during source builds.
          ast-grep = prev.ast-grep.overrideAttrs (_: {
            doCheck = false;
          });

          # direnv's GNUmakefile unconditionally enables `-linkmode=external`
          # on Darwin, but nixpkgs builds direnv with `CGO_ENABLED=0`.
          # Remove that linker flag so static non-CGO builds succeed again.
          direnv = prev.direnv.overrideAttrs (old: {
            postPatch = (old.postPatch or "") + ''
              substituteInPlace GNUmakefile \
                --replace-warn "GO_LDFLAGS += -linkmode=external" ""
            '';
          });

          # Nushell 0.112.1 currently fails Darwin sandboxed REPL tests with
          # permission errors while checking `env_shlvl_in_repl` and
          # `env_shlvl_in_exec_repl`. Skip checks until nixpkgs updates to a
          # fixed revision.
          nushell =
            if prev.nushell.version == "0.112.1" then
              prev.nushell.overrideAttrs (_: {
                doCheck = false;
              })
            else
              prev.nushell;
        };

      mkDarwinConfig =
        {
          system ? "aarch64-darwin",
          username,
          lite ? false,
        }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        darwin.lib.darwinSystem {
          inherit system;
          modules = [
            ./darwin.nix
            nix-homebrew.darwinModules.nix-homebrew
            {
              _module.args = {
                inherit
                  username
                  lite
                  ifiokjr-nixpkgs
                  homebrew-core
                  homebrew-cask
                  homebrew-bundle
                  ;
              };
            }
            # Integrate home-manager directly with nix-darwin
            home-manager.darwinModules.home-manager
            {
              nixpkgs.overlays = [ darwinWorkaroundsOverlay ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit ifiokjr-nixpkgs lite;
              };
              home-manager.users.${username} = {
                imports = [ ./home.nix ];
                home.username = username;
                home.homeDirectory = "/Users/${username}";
              };
            }
          ];
        };

      # Helper to create standalone home-manager configurations (for Linux or standalone use)
      makeHomeManagerConfiguration =
        {
          system,
          username,
          lite ? false,
          homeDirectory ? null,
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ darwinWorkaroundsOverlay ];
          };
          # Automatically determine home directory based on system
          finalHomeDirectory =
            if homeDirectory != null then
              homeDirectory
            else if pkgs.stdenv.isLinux then
              "/home/${username}"
            else
              "/Users/${username}";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit ifiokjr-nixpkgs lite;
          };
          modules = [
            ./home.nix
            {
              home = {
                homeDirectory = finalHomeDirectory;
                inherit username;
                stateVersion = "25.11";
              };
            }
          ];
        };

      # Load machine-specific configuration from machine.nix
      # This file is gitignored and should exist at the flake location
      #
      # Since machine.nix is gitignored, it won't be copied to the Nix store.
      # We use impure evaluation to read from NIX_USER_CONFIG_DIR (set by rebuild script)
      # or fall back to the flake's directory via self.outPath + "/machine.nix"
      loadMachineConfig =
        let
          # Use NIX_USER_CONFIG_DIR if set (passed through sudo by rebuild script)
          # Falls back to self.outPath for backwards compatibility
          configDir = builtins.getEnv "NIX_USER_CONFIG_DIR";
          configPath = if configDir != "" then configDir + "/machine.nix" else self.outPath + "/machine.nix";
        in
        if builtins.pathExists configPath then
          import configPath
        else
          throw ''
            machine.nix not found!

            Expected location: ${toString configPath}

            This file should be created from machine.nix.example.

            To fix this:
              1. Run: generate-machine-config
              2. Or manually: cp machine.nix.example machine.nix (in this directory)
              3. Then edit machine.nix with your settings

            The file is gitignored and specific to each machine.

            Note: This requires --impure flag since machine.nix is gitignored.
            Use --skip-check with the rebuild script to bypass flake check.
          '';
    in
    {
      # Build darwin flake using:
      #   sudo NIX_USER_CONFIG_DIR=~/.config/nix darwin-rebuild switch --flake ~/.config/nix --impure
      #
      # Or use the rebuild script (recommended):
      #   rebuild
      #
      # The configuration is read from machine.nix in NIX_USER_CONFIG_DIR.
      # --impure flag is required to read gitignored machine.nix via env var.

      # Default configuration loaded from machine.nix
      darwinConfigurations.default =
        let
          machineConfig = loadMachineConfig;
        in
        mkDarwinConfig {
          system = machineConfig.system;
          username = machineConfig.username;
          lite = machineConfig.lite or false;
        };

      # Standalone home-manager configuration (for Linux or non-Darwin use)
      # Only evaluated when explicitly requested
      homeConfigurations =
        let
          machineConfig = loadMachineConfig;
        in
        {
          "${machineConfig.username}@${machineConfig.system}" = makeHomeManagerConfiguration {
            system = machineConfig.system;
            username = machineConfig.username;
            lite = machineConfig.lite or false;
          };
        };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [ darwinWorkaroundsOverlay ];
          };
        in
        {
          ci-nushell = pkgs.nushell;
        }
      );
    };
}
