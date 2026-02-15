{
  config,
  pkgs,
  self,
  username,
  nix-casks,
  ...
}:

let
  casks = nix-casks.packages.${pkgs.stdenv.system};

  # Custom packages (apps not available in nix-casks)
  google-chrome-custom = pkgs.callPackage ./packages/google-chrome.nix { };
  steam-custom = pkgs.callPackage ./packages/steam.nix { };
  google-drive-custom = pkgs.callPackage ./packages/google-drive.nix { };
  gpg-suite-custom = pkgs.callPackage ./packages/gpg-suite.nix { };
  nordvpn-custom = pkgs.callPackage ./packages/nordvpn.nix { };
  zoom-custom = pkgs.callPackage ./packages/zoom.nix { };
in
{
  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  # User configuration
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
    shell = pkgs.nushell;
  };

  # Set primary user for darwin options that require it
  system.primaryUser = username;

  # System-level packages (only those that require system integration)
  # Most packages are now managed in home.nix
  environment.systemPackages =
    (with pkgs; [
      # macOS-specific system utilities
      mkalias # For creating app aliases in /Applications
      tart # macOS VMs on Apple Silicon

      # Core system libraries that other packages depend on
      apple-sdk_15
      libiconv
      fontconfig
      freetype
      jdk # Some system tools may need Java
    ])
    ++ (map (name: casks.${name}) [
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
      "godot"
      "orbstack"
      "podman-desktop"
      "react-native-debugger"
      "reactotron"
      "visual-studio-code"
      "zed"

      # Media & Graphics
      "blender"
      "obs"
      "ollama-app"
      "vlc"

      # Utilities
      "alt-tab"
      "flux-app"
      "geekbench"
      "ledger-live"
      "qbittorrent"
      "the-unarchiver"
      "vysor"

      # Android
      "duet"
    ])
    ++ [
      # Custom packages (apps not available in nix-casks)
      google-chrome-custom
      google-drive-custom
      gpg-suite-custom
      nordvpn-custom
      steam-custom
      zoom-custom
    ];

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
      echo "setting up /Applications..." >&2
      rm -rf /Applications/Nix\ Apps
      mkdir -p /Applications/Nix\ Apps
      find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
      while IFS= read -r src; do
        app_name=$(basename "$src")
        echo "copying $src" >&2
        ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
      done
    '';

  # Necessary for using flakes on this system.
  nix.settings.experimental-features = "nix-command flakes";

  # Enable alternative shell support in nix-darwin.
  # programs.fish.enable = true;

  # Set Git commit hash for darwin-version.
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
      AppleShowAllExtensions = true;
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
      AppleShowAllExtensions = true;
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
  };
}
