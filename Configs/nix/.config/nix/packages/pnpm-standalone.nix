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
  version = "10.29.3";

  # Platform and architecture mapping
  platform = if stdenv.isDarwin then "macos" else "linux";
  arch = if stdenv.isAarch64 then "arm64" else "x64";

  # SHA256 hashes for different platforms
  # Using fakeSha256 initially - Nix will provide correct hash on first build
  hashes = {
    "macos-arm64" = "sha256-okjFawqyBEPhjQyO4yB8bFZO40K9P8hpSzVpoGDOzs4=";
    "macos-x64" = "sha256-Vph3Al6IlNiLF1b9vAZ1Mw382cAezkqyZoW6r/+o4wM=";
    "linux-arm64" = "sha256-rnAgiIKyxSKeFD3iRU/E93iy0q6Vmi5I7Hamwm6LMSc=";
    "linux-x64" = "sha256-L8mNsSfGEb4MEQrxG1tydZ99c2iT3dyB33O3tZsw8Vo=";
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
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

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
