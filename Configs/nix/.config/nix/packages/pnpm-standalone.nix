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
  version = "10.30.2";

  # Platform and architecture mapping
  platform = if stdenv.isDarwin then "macos" else "linux";
  arch = if stdenv.isAarch64 then "arm64" else "x64";

  # SHA256 hashes for different platforms
  # Using fakeSha256 initially - Nix will provide correct hash on first build
  hashes = {
    "macos-arm64" = "sha256-lveWjIJVm6fs0nkXFJH9UF1Xo5+H0jzQ/j0+B4G64xE=";
    "macos-x64" = "sha256-G4SeZQSznCtaiCgIMLpZRY6JJlAgLdFF2DVTlNTflTI=";
    "linux-arm64" = "sha256-vCX8zmwF6lUdeNK3LIW4Bo31afk/3BX39qzAAogCTv8=";
    "linux-x64" = "sha256-jglTYI+qHfMhh+eo/3PiwUiyi1LDhg6b3gwT0I2ji8k=";
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
