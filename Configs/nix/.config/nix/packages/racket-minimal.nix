{
  stdenv,
  fetchurl,
  lib,
  autoPatchelfHook,
  makeWrapper,
  openssl,
  zlib,
}:

# The upstream racket-minimal fails to build from source on macOS because the
# Nix build sandbox prevents configure test programs from executing (Chez Scheme
# and rktio both use AC_RUN_IFELSE checks that fail under sandbox restrictions).
#
# This package uses the official pre-built Racket minimal binaries instead.

let
  version = "9.0";

  arch = if stdenv.isAarch64 then "aarch64" else "x86_64";
  os = if stdenv.isDarwin then "macosx" else "linux-buster";

  hashes = {
    "aarch64-macosx" = "sha256-Iyk7oMMpLJP6NBuf7uX4kwVSBNOZI4gOYGyC0VCej/I=";
    "x86_64-macosx" = "sha256-BRn/s02MGUqaIysM0SyeGbhznz+DZXsF3sUr9O/u2Sc=";
    "aarch64-linux-buster" = "sha256-HwPIo5KUV00ysqOqIoy5+QPURxy0+kG+MuscRgTQnHM=";
    "x86_64-linux-buster" = "sha256-FiYhLe7S5SOD0Qz6fmd1/Ty4QsCUxYQdzjV+i+moSek=";
  };
in
stdenv.mkDerivation {
  pname = "racket-minimal";
  inherit version;

  src = fetchurl {
    url = "https://mirror.racket-lang.org/installers/${version}/racket-minimal-${version}-${arch}-${os}-cs.tgz";
    hash = hashes."${arch}-${os}";
  };

  sourceRoot = "racket";

  nativeBuildInputs = lib.optionals stdenv.isLinux [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = lib.optionals stdenv.isLinux [
    openssl
    zlib
  ];

  dontBuild = true;
  dontStrip = true;
  dontFixup = stdenv.isDarwin;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r bin collects etc include lib share $out/
    cp -r man $out/share/ 2>/dev/null || true

    runHook postInstall
  '';

  # Racket loads libssl via dlopen at runtime (FFI), which autoPatchelfHook
  # cannot patch. Wrap the binaries with LD_LIBRARY_PATH so dlopen finds it.
  postFixup = lib.optionalString stdenv.isLinux ''
    for bin in racket raco; do
      wrapProgram $out/bin/$bin \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ openssl ]}
    done
  '';

  meta = with lib; {
    description = "Programmable programming language (minimal distribution, pre-built)";
    homepage = "https://racket-lang.org/";
    license = with licenses; [
      asl20
      mit
    ];
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "racket";
  };
}
