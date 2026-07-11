{
  description = "System flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    darwin.url = "github:nix-darwin/nix-darwin/master";
    darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/master";
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

          # cctools ld 1010.6 crashes while linking Starship 1.26.0 from source
          # on macOS 26, even without cargo-auditable metadata. Use Starship's
          # hash-pinned official Darwin binary until cctools is fixed upstream.
          starship =
            let
              release =
                if prev.stdenv.hostPlatform.isAarch64 then
                  {
                    target = "aarch64-apple-darwin";
                    hash = "sha256-xAsnsR9YBBHgaPL6bBvngwo4fAvEepTR038ysFTFNh0=";
                  }
                else
                  {
                    target = "x86_64-apple-darwin";
                    hash = "sha256-VUj0BqS29WlZA73qg/d85H7BLIwOYtq9MxItjxM+Qgc=";
                  };
            in
            prev.stdenvNoCC.mkDerivation {
              inherit (prev.starship) pname version;
              src = prev.fetchurl {
                url = "https://github.com/starship/starship/releases/download/v${prev.starship.version}/starship-${release.target}.tar.gz";
                inherit (release) hash;
              };
              dontUnpack = true;
              nativeBuildInputs = [ prev.installShellFiles ];
              installPhase = ''
                runHook preInstall
                tar -xzf $src
                install -Dm755 starship $out/bin/starship
                installShellCompletion --cmd starship \
                  --bash <($out/bin/starship completions bash) \
                  --fish <($out/bin/starship completions fish) \
                  --zsh <($out/bin/starship completions zsh)
                runHook postInstall
              '';
              meta = prev.starship.meta;
            };

          # vfkit 0.6.3 currently crashes Darwin cctools `ld` while linking on
          # macOS 26 / clang-wrapper 21.1.8. Podman also supports krunkit on
          # Darwin, so mark vfkit unavailable and rebuild podman with krunkit
          # only until vfkit or cctools is fixed upstream.
          vfkit = prev.vfkit.overrideAttrs (old: {
            meta = old.meta // {
              platforms = [ ];
            };
          });
          podman = prev.podman.override {
            vfkit = final.vfkit;
          };

          # direnv's GNUmakefile unconditionally enables `-linkmode=external`
          # on Darwin, but nixpkgs builds direnv with `CGO_ENABLED=0`.
          # Remove that linker flag so static non-CGO builds succeed again.
          # direnv 2.37.1 can also hang indefinitely in checkPhase on Darwin
          # after a nixpkgs update, so disable checks for that affected release.
          direnv = prev.direnv.overrideAttrs (
            old:
            {
              postPatch = (old.postPatch or "") + ''
                substituteInPlace GNUmakefile \
                  --replace-warn "GO_LDFLAGS += -linkmode=external" ""
              '';
            }
            // prev.lib.optionalAttrs (prev.direnv.version == "2.37.1") {
              doCheck = false;
            }
          );

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

          # mise's `oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits`
          # asserts that `bin/helper` retains mode 0o4755 (setuid) after OCI layer
          # extraction. The Nix Darwin sandbox builds as a non-root `nixbld` user,
          # which cannot preserve setuid bits, so the extracted file ends up 0o755
          # and the test panics (`left: 493, right: 2541`). This is fundamentally
          # unsatisfiable in a sandboxed non-root build, so skip just that test and
          # keep the rest of mise's suite (1349 passing tests). Append to upstream's
          # existing `checkFlags` (which already skips other sandbox-incompatible
          # tests) without clobbering it, and handle both string and list forms.
          mise = prev.mise.overrideAttrs (
            old:
            let
              skipFlag = "--skip=oci::layer::tests::preserve_metadata_dir_layer_keeps_special_permission_bits";
              existing = old.checkFlags or [ ];
            in
            {
              checkFlags =
                if prev.lib.isString existing then "${existing} ${skipFlag}" else existing ++ [ skipFlag ];
            }
          );
        };

      # Overlay consulted by `dot rebuild`'s auto-recovery: when an upstream
      # package's test suite fails in the sandboxed Nix build (e.g. setuid /
      # permission tests that can't pass as non-root `nixbld`), the rebuild
      # wrapper re-runs the switch with `DOT_DISABLE_CHECKS_PKGS` set to the
      # failing package names. This overlay then sets `doCheck = false` for those
      # packages so the build completes and activation proceeds, after which the
      # wrapper prints a clear warning telling you to add a permanent workaround
      # in `darwinWorkaroundsOverlay`. Requires `--impure` (already used by the
      # rebuild command) because `builtins.getEnv` is impure.
      disableChecksOverlay =
        final: prev:
        let
          raw = builtins.getEnv "DOT_DISABLE_CHECKS_PKGS";
          names = prev.lib.filter (s: s != "") (prev.lib.splitString " " raw);
          disable =
            acc: name:
            if prev ? ${name} then
              acc
              // {
                ${name} = prev.${name}.overrideAttrs (_: {
                  doCheck = false;
                });
              }
            else
              acc;
        in
        prev.lib.foldl' disable prev names;

      mkDarwinConfig =
        {
          system ? "aarch64-darwin",
          username,
          lite ? false,
          isDesktop ? false,
          alwaysOn ? false,
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
                  isDesktop
                  alwaysOn
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
              nixpkgs.overlays = [
                darwinWorkaroundsOverlay
                disableChecksOverlay
              ];
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit
                  ifiokjr-nixpkgs
                  lite
                  isDesktop
                  alwaysOn
                  ;
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
          isDesktop ? false,
          alwaysOn ? false,
          homeDirectory ? null,
        }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              darwinWorkaroundsOverlay
              disableChecksOverlay
            ];
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
            inherit
              ifiokjr-nixpkgs
              lite
              isDesktop
              alwaysOn
              ;
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
          # Prefer the explicit user config directory passed by rebuild/setup.
          configDir = builtins.getEnv "NIX_USER_CONFIG_DIR";
          homeDir = builtins.getEnv "HOME";
          candidatePaths = builtins.filter (path: path != "") [
            (if configDir != "" then configDir + "/machine.nix" else "")
            # Some CI/home-manager entry points do not preserve
            # NIX_USER_CONFIG_DIR, but HOME remains available with --impure.
            (if homeDir != "" then homeDir + "/.config/nix/machine.nix" else "")
            # Backwards-compatible fallback for callers that keep machine.nix
            # next to the flake itself.
            (self.outPath + "/machine.nix")
          ];
          configPath = builtins.head (builtins.filter builtins.pathExists candidatePaths);
        in
        if builtins.any builtins.pathExists candidatePaths then
          import configPath
        else
          throw ''
            machine.nix not found!

            Checked locations:
            ${builtins.concatStringsSep "\n" (map (path: "  - " + toString path) candidatePaths)}

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
          isDesktop = machineConfig.isDesktop or false;
          alwaysOn = machineConfig.alwaysOn or false;
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
            isDesktop = machineConfig.isDesktop or false;
            alwaysOn = machineConfig.alwaysOn or false;
          };
        };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              darwinWorkaroundsOverlay
              disableChecksOverlay
            ];
          };
        in
        {
          ci-nushell = pkgs.nushell;
        }
      );

      # Formatter for `nix fmt`
      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
            overlays = [
              darwinWorkaroundsOverlay
              disableChecksOverlay
            ];
          };
        in
        pkgs.nixfmt
      );
    };
}
