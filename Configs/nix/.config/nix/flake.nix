{
  description = "Darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    # Optional: Declarative tap management
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
      nix-homebrew,
      homebrew-core,
      homebrew-cask,
      homebrew-bundle,
    }:
    let
      # Helper function to create configurations for a specific user
      mkDarwinConfig =
        {
          system ? "aarch64-darwin",
          username,
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
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                user = username;
                autoMigrate = true;

                # Optional: Declarative tap management
                taps = {
                  "homebrew/homebrew-core" = homebrew-core;
                  "homebrew/homebrew-cask" = homebrew-cask;
                  "homebrew/homebrew-bundle" = homebrew-bundle;
                };

                # Optional: Enable fully-declarative tap management
                #
                # With mutableTaps disabled, taps can no longer be added imperatively with `brew tap`.
                mutableTaps = false;
              };
            }
            # Optional: Align homebrew taps config with nix-homebrew
            (
              { config, ... }:
              {
                homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
              }
            )
            # Pass the username to darwin.nix
            {
              _module.args = {
                inherit username;
              };
            }
            # Integrate home-manager directly with nix-darwin
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
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
          homeDirectory ? null,
        }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
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
      # We use impure evaluation to read from DARWIN_USER_CONFIG_DIR (set by rebuild script)
      # or fall back to the flake's directory via self.outPath + "/machine.nix"
      loadMachineConfig =
        let
          # Use DARWIN_USER_CONFIG_DIR if set (passed through sudo by rebuild script)
          # Falls back to self.outPath for backwards compatibility
          configDir = builtins.getEnv "DARWIN_USER_CONFIG_DIR";
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
      #   sudo DARWIN_USER_CONFIG_DIR=~/.config/nix darwin-rebuild switch --flake ~/.config/nix --impure
      #
      # Or use the rebuild script (recommended):
      #   rebuild
      #
      # The configuration is read from machine.nix in DARWIN_USER_CONFIG_DIR.
      # --impure flag is required to read gitignored machine.nix via env var.

      # Default configuration loaded from machine.nix
      darwinConfigurations.default =
        let
          machineConfig = loadMachineConfig;
        in
        mkDarwinConfig {
          system = machineConfig.system;
          username = machineConfig.username;
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
          };
        };
    };
}
