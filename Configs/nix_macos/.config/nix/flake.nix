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
    yazelix-hm = {
      # Path is relative to this flake.nix
      # Works on both macOS and Linux since yazelix is in dotfiles
      url = "path:../../../yazelix/.config/yazelix/home_manager";
      inputs.nixpkgs.follows = "nixpkgs";
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
      yazelix-hm,
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
                imports = [
                  ./home.nix
                  yazelix-hm.homeManagerModules.default
                ];
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
            yazelix-hm.homeManagerModules.default
            {
              home = {
                homeDirectory = finalHomeDirectory;
                inherit username;
                stateVersion = "25.11";
              };
            }
          ];
        };

      # Dynamically detect the current user from environment when using --impure
      # Falls back to "default" if USER env var is not set
      currentUser = builtins.getEnv "USER";
      defaultUsername = if currentUser != "" then currentUser else "default";
    in
    {
      # Build darwin flake using one of these methods:
      #
      # macOS (darwin-rebuild):
      #   Method 1 (Recommended): darwin-rebuild switch --flake .#$(whoami)
      #   Method 2 (Impure): darwin-rebuild switch --flake .# --impure
      #
      # Linux or standalone home-manager:
      #   home-manager switch --flake .#username@system
      #   Example: home-manager switch --flake .#alice@x86_64-linux
      #
      # Note: On macOS with darwin-rebuild, home-manager is integrated,
      # so you only need to run darwin-rebuild.

      # ===== Darwin Configurations (macOS with integrated home-manager) =====

      # Default configuration (works with --impure for auto-detection)
      darwinConfigurations.${defaultUsername} = mkDarwinConfig {
        system = "aarch64-darwin";
        username = defaultUsername;
      };

      # Named darwin configurations
      # Add your own users here:
      darwinConfigurations.ifiokjr = mkDarwinConfig {
        system = "aarch64-darwin";
        username = "ifiokjr";
      };

      # Uncomment and add more users as needed:
      # darwinConfigurations.alice = mkDarwinConfig {
      #   system = "aarch64-darwin";
      #   username = "alice";
      # };
      #
      # darwinConfigurations.bob = mkDarwinConfig {
      #   system = "x86_64-darwin";  # Intel Mac
      #   username = "bob";
      # };

      # ===== Standalone Home Manager Configurations (for Linux or standalone use) =====

      # Default standalone configuration (works with --impure)
      homeConfigurations."${defaultUsername}@aarch64-darwin" = makeHomeManagerConfiguration {
        system = "aarch64-darwin";
        username = defaultUsername;
      };

      homeConfigurations."${defaultUsername}@x86_64-linux" = makeHomeManagerConfiguration {
        system = "x86_64-linux";
        username = defaultUsername;
      };

      homeConfigurations."${defaultUsername}@aarch64-linux" = makeHomeManagerConfiguration {
        system = "aarch64-linux";
        username = defaultUsername;
      };

      # Named standalone configurations
      homeConfigurations."ifiokjr@aarch64-darwin" = makeHomeManagerConfiguration {
        system = "aarch64-darwin";
        username = "ifiokjr";
      };

      homeConfigurations."ifiokjr@x86_64-linux" = makeHomeManagerConfiguration {
        system = "x86_64-linux";
        username = "ifiokjr";
      };

      # Add more as needed:
      # homeConfigurations."alice@x86_64-linux" = makeHomeManagerConfiguration {
      #   system = "x86_64-linux";
      #   username = "alice";
      # };
    };
}
