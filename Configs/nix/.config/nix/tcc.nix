# tcc.nix - Declarative macOS TCC (Privacy & Security) permission grants
#
# macOS TCC permissions (Accessibility, Full Disk Access, Screen Recording, ...)
# normally require manual toggles in System Settings. This module grants them
# declaratively by writing rows into the system TCC database during activation.
#
# One-time prerequisite: the terminal running `dot rebuild` needs Full Disk
# Access so the activation script can write the TCC database. Without it the
# script skips grants with a warning instead of failing the rebuild. After
# that, every rebuild re-applies the grants below automatically.
#
# Smart installs: before granting, bundle-identifier clients are checked via
# Spotlight (with a LaunchServices fallback). Apps that are not installed are
# skipped with a message, so a lite machine without e.g. Slack never breaks —
# and if an app is installed later, the next rebuild grants it automatically.
#
# Notes:
#   - Clients that start with "/" are treated as absolute binary paths
#     (re-granted on every rebuild, so nix store path churn is handled);
#     anything else is treated as a bundle identifier (preferred: for
#     Developer ID-signed apps the grant survives app updates).
#   - Grants are written with csreq=NULL: the client is matched by path or
#     bundle identifier. Acceptable for personal machines; MDM PPPC profiles
#     are the stricter, Apple-sanctioned alternative.
#   - kTCCServiceAppleEvents (Automation) is intentionally not supported here:
#     it needs one row per target app (indirect_object_identifier). Add those
#     manually if a specific automation target is needed.
#   - Find an app's bundle identifier with:
#       osascript -e 'id of app "Ghostty"'
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles.tcc;

  # Friendly service names -> kTCCService constants used in TCC.db rows.
  tccServices = {
    accessibility = "kTCCServiceAccessibility";
    full-disk-access = "kTCCServiceSystemPolicyAllFiles";
    screen-recording = "kTCCServiceScreenCapture";
    input-monitoring = "kTCCServiceListenEvent";
    post-event = "kTCCServicePostEvent";
    app-management = "kTCCServiceAppManagement";
    desktop-folder = "kTCCServiceSystemPolicyDesktopFolder";
    documents-folder = "kTCCServiceSystemPolicyDocumentsFolder";
    downloads-folder = "kTCCServiceSystemPolicyDownloadsFolder";
    network-volumes = "kTCCServiceSystemPolicyNetworkVolumes";
    removable-volumes = "kTCCServiceSystemPolicyRemovableVolumes";
    camera = "kTCCServiceCamera";
    microphone = "kTCCServiceMicrophone";
  };

  # Named columns keep the INSERT working across macOS versions regardless of
  # extra columns (boots_count, is_deleted, ...) the access table gains.
  # auth_value=2 means allowed; client_type 0 = bundle identifier, 1 = path.
  # The || echo keeps activation alive when a single grant fails (e.g. a
  # transient database lock); the failure stays visible in the output.
  insertGrant = client: service: ''
    /usr/bin/sqlite3 "$TCC_DB" "INSERT OR REPLACE INTO access(service, client, client_type, auth_value, auth_reason, auth_version, csreq, policy_id, indirect_object_identifier_type, indirect_object_identifier, indirect_object_code_identity, flags, last_modified) VALUES('${service}', '${client}', ${
      if lib.hasPrefix "/" client then "1" else "0"
    }, 2, 4, 1, NULL, NULL, 0, 'UNUSED', NULL, 0, $NOW);" 2>/dev/null || echo "==> TCC: WARNING: grant failed: ${service} -> ${client}"
  '';

  # Emit the grant block for one client:
  #   - path-based clients are skipped when the binary is not present;
  #   - bundle identifiers are checked against Spotlight first (fast) with a
  #     LaunchServices fallback, so apps that are not installed (e.g. on lite
  #     machines) are skipped gracefully instead of writing dead rows.
  clientBlock =
    client: services:
    let
      resolved = map (name: tccServices.${name}) services;
      grants = lib.concatMapStrings (service: insertGrant client service) resolved;
    in
    if lib.hasPrefix "/" client then
      ''
        if [[ -e "${client}" ]]; then
        ${grants}      else
          echo "==> TCC: client not found, skipping: ${client}"
        fi
      ''
    else
      ''
        if app_installed "${client}"; then
        ${grants}      else
          echo "==> TCC: app not installed, skipping: ${client}"
        fi
      '';

  grantScript = lib.concatStrings (lib.mapAttrsToList clientBlock cfg.allow);
in
{
  options.dotfiles.tcc = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = pkgs.stdenv.hostPlatform.isDarwin;
      description = "Whether to apply declarative TCC permission grants during activation.";
    };

    allow = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf (lib.types.enum (builtins.attrNames tccServices)));
      default = {
        # Ghostty is the primary terminal: grant everything a terminal (and the
        # processes launched from it) can plausibly need.
        "com.mitchellh.ghostty" = [
          "accessibility"
          "full-disk-access"
          "screen-recording"
          "input-monitoring"
          "post-event"
          "app-management"
          "desktop-folder"
          "documents-folder"
          "downloads-folder"
          "network-volumes"
          "removable-volumes"
          # camera/microphone are deliberately not granted: any process spawned
          # from the terminal would silently inherit them. Uncomment to grant.
          # "camera"
          # "microphone"
        ];

        # Browsers: Google Meet video calls and screen sharing/mirroring.
        "com.google.Chrome" = [
          "accessibility"
          "screen-recording"
          "camera"
          "microphone"
        ];

        # Communication / video calling apps.
        "com.tinyspeck.slackmacgap" = [
          "camera"
          "microphone"
          "screen-recording"
        ];
        "us.zoom.xos" = [
          "camera"
          "microphone"
          "screen-recording"
        ];
        "com.hnc.Discord" = [
          "camera"
          "microphone"
          "screen-recording"
        ];

        # Duet Display: input bridging (accessibility) + screen mirroring.
        "com.kairos.duetMac" = [
          "accessibility"
          "post-event"
          "screen-recording"
        ];

        # Window management / launcher: accessibility is their core function.
        "com.lwouis.alt-tab-macos" = [
          "accessibility"
        ];
        "com.raycast.macos" = [
          "accessibility"
        ];

        # Media capture / streaming.
        "com.obsproject.obs-studio" = [
          "screen-recording"
          "camera"
          "microphone"
        ];
        "com.reincubate.macos.cam" = [
          "camera"
        ];
        "com.openai.codex" = [
          "microphone"
          "screen-recording"
        ];

        # Virtualization: input sharing between host and VMs.
        "com.parallels.desktop.console" = [
          "accessibility"
        ];
      };
      description = ''
        Map of TCC clients (bundle identifier or absolute binary path) to the
        list of TCC services to grant each of them. Clients whose app is not
        installed are skipped during activation.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.tcc.text = ''
      # ── Declarative TCC permission grants (managed by tcc.nix) ─────────
      TCC_DB="/Library/Application Support/com.apple.TCC/TCC.db"
      NOW="$(date +%s)"

      # Skip gracefully when the terminal lacks Full Disk Access: even root
      # cannot read or write the TCC database without it. Structured as
      # if/else (never `exit`) so the surrounding activation is unaffected.
      if [[ ! -f "$TCC_DB" ]] || ! /usr/bin/sqlite3 "$TCC_DB" "SELECT 1" >/dev/null 2>&1; then
        echo "==> TCC: database not accessible - grant Full Disk Access to the terminal running rebuild; skipping TCC grants"
      else
        ${grantScript}
        # Restart tccd so new grants are picked up immediately
        /usr/bin/launchctl stop com.apple.tccd 2>/dev/null || true
        echo "==> TCC: permissions granted"
      fi

      # Bundle-identifier existence check: Spotlight first (fast), then
      # LaunchServices for machines where Spotlight has not indexed yet.
      app_installed() {
        local bundle_id="$1"
        if [[ -n "$(/usr/bin/mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null | head -n 1)" ]]; then
          return 0
        fi
        /usr/bin/osascript -e "id of application id \"$bundle_id\"" >/dev/null 2>&1
      }

      ${grantScript}
      # Restart tccd so new grants are picked up immediately
      /usr/bin/launchctl stop com.apple.tccd 2>/dev/null || true
      echo "==> TCC: permissions granted"
    '';
  };
}
