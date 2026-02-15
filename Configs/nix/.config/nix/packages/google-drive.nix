{
  stdenv,
  fetchurl,
  undmg,
  lib,
}:

# To update:
# 1. Set hash to lib.fakeHash
# 2. Run rebuild - Nix will show the correct hash in the error
# 3. Copy the correct hash here
# Note: Google Drive uses a rolling URL so the hash changes with each release
stdenv.mkDerivation {
  pname = "google-drive";
  version = "latest";

  src = fetchurl {
    url = "https://dl.google.com/drive-file-stream/5-percent/GoogleDrive.dmg";
    hash = "sha256-5exURzHot+M3F3YK8KvWSHxnwte9xkDamAkVj5zf+Tw=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    # DMG contains a .pkg installer; extract the .app from the PKG payload
    /usr/sbin/pkgutil --expand-full *.pkg extracted

    mkdir -p $out/Applications
    find extracted -name "*.app" -maxdepth 4 -type d -not -path "*/.app/*" | while IFS= read -r app; do
      cp -r "$app" $out/Applications/
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Drive desktop client for macOS";
    homepage = "https://www.google.com/drive/";
    license = licenses.unfree;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
