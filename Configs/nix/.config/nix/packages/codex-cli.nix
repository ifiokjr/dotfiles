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
  version = "0.101.0";
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
    "aarch64-apple-darwin" = "sha256-/Ah+kAK+DhcL/qonZZ43eCHhWrl4tKSQde+V21+CB/g=";
    "x86_64-apple-darwin" = "sha256-UdTjUXx18JMxMr4zZfM7CANtQ9PCBpKzD1zDbdPqw+k=";
    "aarch64-unknown-linux-musl" = "sha256-9cSxFHMyocxBCLd2x1nue0CdNl5YMKTllmfh+cfm2mA=";
    "x86_64-unknown-linux-musl" = "sha256-/zY/hZfb8Dg8F2WefJJzW6qZG+irmflnxcw8aLMpJ3w=";
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
