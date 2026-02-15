{
  stdenv,
  fetchurl,
  lib,
}:

let
  # To update version:
  # 1. Check Homebrew cask or Zoom website for latest version
  # 2. Change version number below
  # 3. Set all hashes to lib.fakeHash
  # 4. Run rebuild - Nix will show the correct hash in the error
  # 5. Copy the correct hash here
  version = "6.7.6.75444";

  hashes = {
    "aarch64" = "sha256-MS7hQ43UOAcfogDN6zBpOaLjcTZMJP2dSkAxlkpfVMY=";
    "x86_64" = "sha256-MDNyJ/w7YA2faBbvRwQ+ANrD6PCjKQZk1WLY/2FBsA8=";
  };

  arch = if stdenv.isAarch64 then "aarch64" else "x86_64";

  # arm64 builds have /arm64/ in the URL path; x86_64 does not
  urlPath = if stdenv.isAarch64 then "${version}/arm64" else version;
in
stdenv.mkDerivation {
  pname = "zoom";
  inherit version;

  src = fetchurl {
    url = "https://cdn.zoom.us/prod/${urlPath}/zoomusInstallerFull.pkg";
    hash = hashes.${arch} or lib.fakeHash;
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
    description = "Zoom video conferencing client";
    homepage = "https://zoom.us/";
    license = licenses.unfree;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
