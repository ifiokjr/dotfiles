{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  lib,
}:

let
  # To update version:
  # 1. Run: update:codex:version
  # 2. Or manually change version, set hashes to lib.fakeSha256, rebuild
  version = "0.104.0";
  tag = "rust-v${version}";

  # Platform mapping: Nix system → release asset suffix
  platformSuffix =
    {
      "aarch64-darwin" = "aarch64-apple-darwin";
      "x86_64-darwin" = "x86_64-apple-darwin";
      "aarch64-linux" = "aarch64-unknown-linux-musl";
      "x86_64-linux" = "x86_64-unknown-linux-musl";
    }
    .${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");

  hashes = {
    "aarch64-apple-darwin" = "sha256-twFR4DigVVJNTQAOgLS30VWGFluEdnSgwyFl0R2sJxE=";
    "x86_64-apple-darwin" = "sha256-bKIkT4VgC8C7knRKSAezkALnN4xORzLQm6e7DteU1Ow=";
    "aarch64-unknown-linux-musl" = "sha256-gUyqVfEBbDzOlQ6S4LreBOAOHII5VfbCsCCIPoYtGqY=";
    "x86_64-unknown-linux-musl" = "sha256-4QloDXgyPo6Od7GyI6JXdv7qbgQOsG9QyKQ5D1k8spg=";
  };
in
stdenv.mkDerivation {
  pname = "codex-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/${tag}/codex-${platformSuffix}.tar.gz";
    sha256 = hashes.${platformSuffix} or lib.fakeSha256;
  };

  dontBuild = true;
  dontStrip = stdenv.isDarwin; # Stripping crashes on macOS with standalone binaries

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp codex-* $out/bin/codex
    chmod +x $out/bin/codex

    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenAI Codex CLI - AI coding assistant for the terminal";
    homepage = "https://github.com/openai/codex";
    license = licenses.asl20;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    mainProgram = "codex";
  };
}
