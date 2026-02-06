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
      # This file should be created from machine.nix.example and is gitignored
      #
      # Try multiple locations to handle different evaluation contexts:
      # 1. ./machine.nix (relative to flake)
      # 2. ${self}/machine.nix (absolute path via self)
      machineConfigPath =
        let
          relPath = ./machine.nix;
          absPath = "${self}/machine.nix";
        in
        if builtins.pathExists relPath then
          relPath
        else if builtins.pathExists absPath then
          absPath
        else
          null;

      machineConfig =
        if machineConfigPath != null then
          import machineConfigPath
        else
          throw ''
            machine.nix not found!

            Checked locations:
              - ./machine.nix (relative to flake)
              - ${self}/machine.nix (absolute path)

            Please create machine.nix from the template:
              cp machine.nix.example machine.nix

            Or run: generate-machine-config

            Then edit machine.nix with your username and system architecture.
          '';
    in
    {
      # Build darwin flake using:
      #   darwin-rebuild switch --flake ~/.config/nix
      #
      # Or use the rebuild script:
      #   rebuild
      #
      # The configuration is read from machine.nix (not tracked in git)

      # Default configuration loaded from machine.nix
      darwinConfigurations.default = mkDarwinConfig {
        system = machineConfig.system;
        username = machineConfig.username;
      };

      # Standalone home-manager configuration (for Linux or non-Darwin use)
      homeConfigurations."${machineConfig.username}@${machineConfig.system}" =
        makeHomeManagerConfiguration {
          system = machineConfig.system;
          username = machineConfig.username;
        };
    };
}
