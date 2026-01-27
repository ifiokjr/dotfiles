{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  lib,
}:

let
  # To update version:
  # 1. Change version number below
  # 2. Set hash to lib.fakeSha256
  # 3. Run rebuild - Nix will show the correct hash in the error
  # 4. Copy the correct hash here
  version = "10.28.2";

  # Platform and architecture mapping
  platform = if stdenv.isDarwin then "macos" else "linux";
  arch = if stdenv.isAarch64 then "arm64" else "x64";

  # SHA256 hashes for different platforms
  # Using fakeSha256 initially - Nix will provide correct hash on first build
  hashes = {
    "macos-arm64" = "sha256-OKI79T2Ri1GS9x7Vjm35YJ2keHkPibIMpfRcPNRtHSw=";
    "macos-x64" = lib.fakeSha256;
    "linux-arm64" = lib.fakeSha256;
    "linux-x64" = lib.fakeSha256;
  };

  platformKey = "${platform}-${arch}";

in
stdenv.mkDerivation {
  pname = "pnpm-standalone";
  inherit version;

  src = fetchurl {
    url = "https://github.com/pnpm/pnpm/releases/download/v${version}/pnpm-${platformKey}";
    sha256 = hashes.${platformKey} or lib.fakeSha256;
  };

  dontUnpack = true;
  dontBuild = true;
  dontStrip = stdenv.isDarwin; # Stripping crashes on macOS with standalone binaries

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp $src $out/bin/pnpm
    chmod +x $out/bin/pnpm

    runHook postInstall
  '';

  meta = with lib; {
    description = "Fast, disk space efficient package manager (standalone version without Node.js dependency)";
    homepage = "https://pnpm.io/";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    mainProgram = "pnpm";
  };
}
