{
  stdenv,
  fetchurl,
  undmg,
  lib,
}:

let
  # To update version:
  # 1. Check https://gpgtools.org/ for latest version
  # 2. Change version number below
  # 3. Set hash to lib.fakeHash
  # 4. Run rebuild - Nix will show the correct hash in the error
  # 5. Copy the correct hash here
  version = "2023.3";
in
stdenv.mkDerivation {
  pname = "gpg-suite";
  inherit version;

  src = fetchurl {
    url = "https://releases.gpgtools.org/GPG_Suite-${version}.dmg";
    hash = "sha256-V0aKStxV2VTq1P4fiLB+rBtwraQPy8gQdl/VIe8h7vE=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    # DMG contains Install.pkg; extract the .app bundles from the PKG payload
    /usr/sbin/pkgutil --expand-full *.pkg extracted

    mkdir -p $out/Applications
    find extracted -name "*.app" -maxdepth 4 -type d -not -path "*/.app/*" | while IFS= read -r app; do
      cp -r "$app" $out/Applications/
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "GPG Suite for macOS — encryption, signing, and key management";
    homepage = "https://gpgtools.org/";
    license = licenses.gpl3;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
