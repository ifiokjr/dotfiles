{
  stdenv,
  fetchurl,
  lib,
}:

# The upstream racket-minimal fails to build from source on macOS because the
# Nix build sandbox prevents configure test programs from executing (Chez Scheme
# and rktio both use AC_RUN_IFELSE checks that fail under sandbox restrictions).
#
# This package uses the official pre-built Racket minimal binaries instead.

let
  version = "9.0";

  arch = if stdenv.isAarch64 then "aarch64" else "x86_64";

  hashes = {
    "aarch64" = "sha256-Iyk7oMMpLJP6NBuf7uX4kwVSBNOZI4gOYGyC0VCej/I=";
    "x86_64" = "sha256-BRn/s02MGUqaIysM0SyeGbhznz+DZXsF3sUr9O/u2Sc=";
  };
in
stdenv.mkDerivation {
  pname = "racket-minimal";
  inherit version;

  src = fetchurl {
    url = "https://mirror.racket-lang.org/installers/${version}/racket-minimal-${version}-${arch}-macosx-cs.tgz";
    hash = hashes.${arch};
  };

  sourceRoot = "racket";

  dontBuild = true;
  dontStrip = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin collects etc include lib share $out/
    cp -r man $out/share/ 2>/dev/null || true

    runHook postInstall
  '';

  meta = with lib; {
    description = "Programmable programming language (minimal distribution, pre-built)";
    homepage = "https://racket-lang.org/";
    license = with licenses; [ asl20 mit ];
    platforms = [ "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "racket";
  };
}
