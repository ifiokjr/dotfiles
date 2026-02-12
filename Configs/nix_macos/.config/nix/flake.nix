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
      # This file is gitignored and deployed via Tuckr to ~/.config/nix/machine.nix
      #
      # Function to load machine config - lazy evaluation
      # This avoids issues with HOME not being available during flake evaluation
      loadMachineConfig =
        let
          # Try multiple approaches to find the config
          # 1. If HOME is set, use $HOME/.config/nix/machine.nix
          # 2. Try USER-based path as fallback
          homeDir = builtins.getEnv "HOME";
          userName = builtins.getEnv "USER";
          configPath =
            if homeDir != "" then
              "${homeDir}/.config/nix/machine.nix"
            else if userName != "" then
              # Fallback for macOS when HOME isn't set
              "/Users/${userName}/.config/nix/machine.nix"
            else
              # Last resort - will likely fail but provides clear error
              "~/.config/nix/machine.nix";
        in
        if builtins.pathExists configPath then
          import configPath
        else
          throw ''
            machine.nix not found!

            Tried: ${configPath}
            HOME: ${homeDir}
            USER: ${userName}

            This file should be created from machine.nix.example.

            To fix this:
              1. Run: generate-machine-config
              2. Or manually: cp ~/.config/nix/machine.nix.example ~/.config/nix/machine.nix
              3. Then edit ~/.config/nix/machine.nix with your settings

            The file is gitignored and specific to each machine.
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
          "${machineConfig.username}@${machineConfig.system}" =
            makeHomeManagerConfiguration {
              system = machineConfig.system;
              username = machineConfig.username;
            };
        };
    };
}
