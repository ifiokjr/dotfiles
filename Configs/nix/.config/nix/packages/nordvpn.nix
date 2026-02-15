{
  stdenv,
  fetchurl,
  lib,
}:

let
  # To update version:
  # 1. Check Homebrew cask or NordVPN website for latest version
  # 2. Change version number below
  # 3. Set hash to lib.fakeHash
  # 4. Run rebuild - Nix will show the correct hash in the error
  # 5. Copy the correct hash here
  version = "9.13.0";
in
stdenv.mkDerivation {
  pname = "nordvpn";
  inherit version;

  src = fetchurl {
    url = "https://downloads.nordcdn.com/apps/macos/generic/NordVPN-OpenVPN/${version}/NordVPN.pkg";
    hash = "sha256-vpu+XMqx1kzxMXyqQkLF2Br6t8HMY+q8O4PiUgF7AwY=";
  };

  dontUnpack = true;
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    # Extract the .app from the PKG payload
    /usr/sbin/pkgutil --expand-full $src extracted

    mkdir -p $out/Applications
    find extracted -name "*.app" -maxdepth 4 -type d -not -path "*/.app/*" | while IFS= read -r app; do
      cp -r "$app" $out/Applications/
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "NordVPN macOS client";
    homepage = "https://nordvpn.com/";
    license = licenses.unfree;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
