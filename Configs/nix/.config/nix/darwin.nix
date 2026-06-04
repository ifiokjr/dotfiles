{
  config,
  lib,
  pkgs,
  self,
  username,
  lite ? false,
  isDesktop ? false,
  alwaysOn ? false,
  presets ? [ ],
  ifiokjr-nixpkgs,
  homebrew-core,
  homebrew-cask,
  homebrew-bundle,
  ...
}:

{
  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  # User configuration
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.nushell;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDlSgKQ+IIL2bR6mT46DUtplpvs2zvj/e7HyMX+irBIV"
    ];
  };

  # SSH remote login — key-only auth, no root login, allow only the configured user
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      PermitRootLogin no
      AllowUsers ${username}
    '';
  };

  # Set primary user for darwin options that require it
  system.primaryUser = username;

  # nix-homebrew manages the Homebrew installation and taps declaratively.
  # This ensures proper privilege handling during activation (no TTY issues).
  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = username;
    autoMigrate = true;
    taps = {
      "homebrew/homebrew-core" = homebrew-core;
      "homebrew/homebrew-cask" = homebrew-cask;
      "homebrew/homebrew-bundle" = homebrew-bundle;
    };
    mutableTaps = false;
  };

  # System-level packages (only those that require system integration)
  # Most packages are now managed in home.nix
  # GUI apps are managed by Homebrew casks (see homebrew section below)
  environment.systemPackages = (
    with pkgs;
    [
      # macOS-specific system utilities
      mkalias # For creating app aliases in /Applications
      tart # macOS VMs on Apple Silicon
      xcodes # Install and manage multiple Xcode versions
      apple-sdk_26
      libiconv
      fontconfig
      freetype
      jdk # Some system tools may need Java
      cocoapods
      mas
      pinentry_mac
      swiftformat
      swiftlint
    ]
  );

  # Homebrew cask management via nix-darwin
  # Apps are installed natively by Homebrew into /Applications with proper
  # icons, code signing, and Spotlight indexing.
  homebrew = {
    enable = true;
    # Third-party taps are installed declaratively by nix-homebrew above.
    # Keep brew bundle taps limited to the built-in Homebrew taps so activation
    # does not attempt to re-tap root-owned directories as the user.
    taps = [
      "homebrew/homebrew-core"
      "homebrew/homebrew-cask"
      "homebrew/homebrew-bundle"
    ];
    onActivation = {
      # Keep rebuilds predictable and avoid repeated sudo prompts from Homebrew
      # maintenance work on every activation. Declarative installs/removals still
      # apply, but bulk updates should be run explicitly outside `rebuild`.
      # Charles 5.1 is one example of a cask upgrade that triggers nested
      # privileged uninstall/install hooks during activation.
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";
      extraFlags = [
        "--verbose"
      ];
    };
    casks =
      lib.optionals (!lite) [
        # Productivity & Communication
        "1password"
        "discord"
        "figma"
        "setapp"
        "slack"
        "telegram"
        "whatsapp"

        # Browsers
        "brave-browser"
        "firefox"
        "google-chrome"
        "microsoft-edge"

        # Development
        "android-ndk"
        "android-studio"
        "charles"
        "cursor"
        "db-browser-for-sqlite"
        "dbeaver-community"
        "gdevelop"
        "ghostty"
        "podman-desktop"
        "react-native-debugger"
        "reactotron"
        "t3-code"
        "visual-studio-code"
        "zed"

        # Media & Graphics
        "blackhole-16ch"
        "blender"
        "obs"
        "vlc"

        # Utilities
        "alt-tab"
        "flux-app"
        "geekbench"
        "google-drive"
        "gpg-suite"
        "ledger-wallet"
        "nordvpn"
        "qbittorrent"
        "raycast"
        "the-unarchiver"
        "vysor"

        # Gaming
        "steam"

        # Communication
        "duet"
        "zoom"
      ]
      ++ lib.optionals (isDesktop && lite) [
        # Essential desktop apps for lite macOS machines
        "ghostty" # Terminal emulator — needed even in lite mode on desktop machines
      ];
  };

  # Enable the Tailscale background service automatically via launchd.
  services.tailscale.enable = true;
  # Client-side routing (exit nodes, subnet routers) works out of the box on macOS.
  # The `useRoutingFeatures` option only exists in the NixOS tailscale module
  # (it sets IP forwarding and reverse-path filtering, which are Linux-only).

  # Auto-start the podman VM on login for all desktop Macs.
  # `podman machine start` is idempotent — exits cleanly if already running.
  # Uses `script` instead of `ProgramArguments` so nix-darwin wraps it with
  # /bin/wait4path, ensuring the Nix store is mounted before podman runs.
  # The environment PATH includes standard macOS dirs because podman internally
  # shells out to utilities like mkdir(1) and tr(1) which live in /usr/bin.
  launchd.agents.podman-machine = lib.mkIf isDesktop {
    script = ''
      exec ${pkgs.podman}/bin/podman machine start
    '';
    environment = {
      PATH = "${lib.makeBinPath [ pkgs.podman ]}:/usr/bin:/bin:/usr/sbin:/sbin";
    };
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = false;
      StandardOutPath = "/tmp/podman-machine-start.log";
      StandardErrorPath = "/tmp/podman-machine-start.log";
    };
  };

  # Raise system-wide file descriptor limits from the macOS default of 256.
  # Without this, nix builds and tools like devenv frequently hit "Too many open files".
  # This sets kern.maxfiles (soft) and kern.maxfilesperproc (hard) via launchd,
  # and the setrlimit values for child processes.
  launchd.daemons.limit-maxfiles = {
    command = ""; # No-op daemon — exists only to set resource limits at boot
    serviceConfig = {
      SoftResourceLimits.NumberOfFiles = 65536;
      HardResourceLimits.NumberOfFiles = 524288;
      RunAtLoad = true;
    };
  };

  # Use global sudo timestamp so credentials are shared across all processes.
  # Required because nix-darwin's Homebrew module runs `brew bundle` in a
  # different process tree during activation, and brew's internal `sudo`
  # calls (for cask installs) need to reuse the cached credentials.
  # Note: on sudo 1.9+, `!tty_tickets` only gives ppid-based timestamps
  # which don't survive across different process trees. `timestamp_type=global`
  # is the correct setting for this use case.
  # `timestamp_timeout` is set to 15 minutes so a single authentication
  # covers the nix-darwin rebuild without prompting again.
  security.sudo.extraConfig = ''
    Defaults timestamp_type=global
    Defaults timestamp_timeout=15
  '';

  # Enable zsh system-wide
  programs.zsh.enable = true;

  # Register nushell as a valid login shell (adds to /etc/shells)
  environment.shells = with pkgs; [
    bashInteractive
    zsh
    nushell
  ];

  # Set XDG_CONFIG_HOME so nushell uses ~/.config/nushell/ on macOS
  # (without this, nushell defaults to ~/Library/Application Support/nushell/)
  environment.variables.XDG_CONFIG_HOME = "$HOME/.config";

  # Raise file descriptor limit for all login shells.
  # macOS default is 256 which causes "Too many open files" errors during
  # nix builds, devenv, and other heavy workloads.
  # The system-wide limit is set separately via launchd.daemons.limit-maxfiles.
  environment.shellInit = ''
    ulimit -n 65536 2>/dev/null || true
  '';

  system.activationScripts.applications.text =
    let
      env = pkgs.buildEnv {
        name = "system-applications";
        paths = config.environment.systemPackages;
        pathsToLink = [ "/Applications" ];
      };
    in
    pkgs.lib.mkForce ''
      # Set up applications.
      echo "==> Setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while IFS= read -r src; do
        app_name=$(basename "$src")
        echo "aliasing $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Use the official Nix binary cache to avoid building from source
  nix.settings.substituters = [
    "https://cache.nixos.org"
    "https://cache.flakehub.com"
  ];

  # Keep fish intentionally disabled by default.
  # Enable alternative shell support in nix-darwin when you want Fish available.
  # programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
  # Disabled here because version tracking is handled elsewhere in this flake-based setup.
  # system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # The platform is inherited from flake.nix darwinSystem configuration
  # No need to set nixpkgs.hostPlatform here as it's set at the flake level

  system.defaults = {
    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.15;
      expose-group-apps = true;
      launchanim = false;
      mineffect = "scale";
      minimize-to-application = true;
      mru-spaces = false;
      orientation = "bottom";
      show-recents = false;
      showhidden = true;
      static-only = false;
      tilesize = 48;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
    };

    finder = {
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
      _FXSortFoldersFirstOnDesktop = true;
      AppleShowAllExtensions = false;
      AppleShowAllFiles = true;
      CreateDesktop = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "clmv";
      FXRemoveOldTrashItems = true;
      QuitMenuItem = true;
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = false;
      ShowPathbar = true;
      ShowRemovableMediaOnDesktop = true;
      ShowStatusBar = true;
    };

    NSGlobalDomain = {
      # Keyboard
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      AppleKeyboardUIMode = 3;

      # Appearance
      AppleInterfaceStyle = "Dark";
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleFontSmoothing = 1;
      NSUseAnimatedFocusRing = false;

      # Scrolling & navigation
      "com.apple.swipescrolldirection" = true;
      AppleEnableSwipeNavigateWithScrolls = true;
      AppleShowScrollBars = "WhenScrolling";
      NSScrollAnimationEnabled = true;

      # Trackpad & mouse
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.trackpad.enableSecondaryClick" = true;
      "com.apple.trackpad.forceClick" = true;
      "com.apple.trackpad.scaling" = 1.0;

      # Disable all autocorrect
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticInlinePredictionEnabled = false;

      # Expanded dialogs by default
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      NSDocumentSaveNewDocumentsToCloud = false;

      # Sound
      "com.apple.sound.beep.feedback" = 0;

      # Units & time
      AppleICUForce24HourTime = true;
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      AppleTemperatureUnit = "Celsius";

      # Windows
      AppleWindowTabbingMode = "always";
      NSWindowShouldDragOnGesture = true;
      AppleShowAllExtensions = false;
      _HIHideMenuBar = false;
    };

    trackpad = {
      Clicking = true;
      Dragging = false;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
      TrackpadThreeFingerTapGesture = 2;
      ActuationStrength = 1;
      FirstClickThreshold = 1;
      SecondClickThreshold = 1;
    };

    screencapture = {
      disable-shadow = true;
      location = "~/Pictures/Screenshots";
      type = "png";
      show-thumbnail = true;
    };

    controlcenter = {
      BatteryShowPercentage = true;
      Bluetooth = true;
      Sound = true;
    };

    menuExtraClock = {
      IsAnalog = true;
      Show24Hour = true;
      ShowDate = 1;
      ShowDayOfMonth = true;
      ShowDayOfWeek = true;
      ShowSeconds = false;
    };

    spaces.spans-displays = false;

    loginwindow = {
      GuestEnabled = false;
      DisableConsoleAccess = true;
    };

    WindowManager = {
      GloballyEnabled = false;
      EnableStandardClickToShowDesktop = false;
      EnableTiledWindowMargins = true;
      EnableTilingByEdgeDrag = true;
      EnableTilingOptionAccelerator = true;
      EnableTopTilingByEdgeDrag = true;
      StandardHideDesktopIcons = false;
      StandardHideWidgets = false;
    };

    # Automatically install macOS software updates (security patches, OS upgrades).
    # This enables System Preferences → Software Update → "Automatically keep
    # my Mac up to date" and installs available updates automatically.
    SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
  };

  # Enforce minimum macOS version during system activation.
  # Prints a warning if the running macOS version is below the minimum.
  # Security patches are critical — running an outdated macOS version leaves
  # the system vulnerable. Set minimumVersion to the oldest supported release.
  system.activationScripts.minimumMacOSVersion.text =
    let
      minimumVersion = "26.5"; # macOS 26.5+
    in
    ''
      #!/bin/sh
      CURRENT=$(/usr/bin/sw_vers -productVersion)
      MAJOR=$(echo "$CURRENT" | cut -d. -f1)
      MINOR=$(echo "$CURRENT" | cut -d. -f2)
      REQ_MAJOR=$(echo "${minimumVersion}" | cut -d. -f1)
      REQ_MINOR=$(echo "${minimumVersion}" | cut -d. -f2)
      if [ "$MAJOR" -lt "$REQ_MAJOR" ] || { [ "$MAJOR" -eq "$REQ_MAJOR" ] && [ "$MINOR" -lt "$REQ_MINOR" ]; }; then
        echo >&2 ""
        echo >&2 "⚠️  WARNING: macOS version $CURRENT is below minimum ${minimumVersion}"
        echo >&2 "    macOS 26.5+ is required for security compliance."
        echo >&2 "    Run: rebuild --update-os"
        echo >&2 ""
      fi
    '';

  # ── Always-on mode ──────────────────────────────────────────────────────
  # When alwaysOn=true and running macOS, the machine never sleeps and the
  # screensaver activates instead.  Intended for always-plugged-in desktops
  # and servers (e.g. Mac Mini) that must stay reachable at all times.
  #
  # • Computer sleep  → never (system stays fully awake)
  # • Display sleep   → 10 min (saves power, triggers screensaver)
  # • Hard disk sleep  → never
  # • Screensaver      → enabled with password lock after 5 s grace
  #   (uses the default macOS screensaver — Aerial on supported machines)
  #
  # Uses pmset directly instead of nix-darwin's power.sleep module because
  # that module uses `systemsetup`, which doesn't persist settings across
  # reboots on Apple Silicon. Similarly, system.defaults.screensaver has
  # known reliability issues (nix-darwin #908, #1207).
  system.activationScripts.alwaysOn = lib.optionalString (alwaysOn && pkgs.stdenv.isDarwin) ''
    echo "==> Configuring always-on power management (pmset)..."
    /usr/sbin/pmset -a sleep 0 displaysleep 10 disksleep 0
    echo "==> Enabling screensaver password lock..."
    /usr/bin/defaults -currentHost write com.apple.screensaver askForPassword -int 1
    /usr/bin/defaults -currentHost write com.apple.screensaver askForPasswordDelay -int 5
  '';
}
