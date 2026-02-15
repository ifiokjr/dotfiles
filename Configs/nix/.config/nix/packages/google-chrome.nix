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
# Note: Google Chrome uses a rolling URL so the hash changes with each release
stdenv.mkDerivation {
  pname = "google-chrome";
  version = "latest";

  src = fetchurl {
    url = "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg";
    hash = "sha256-+B22PmRdySDsBuTxzd5fry4+w/vWa7r7+97pM1K6zKA=";
  };

  nativeBuildInputs = [ undmg ];
  sourceRoot = ".";
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r "Google Chrome.app" $out/Applications/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Chrome web browser";
    homepage = "https://www.google.com/chrome/";
    license = licenses.unfree;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
