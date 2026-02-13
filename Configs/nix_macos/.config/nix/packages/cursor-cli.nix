{
  stdenv,
  fetchurl,
  autoPatchelfHook,
  lib,
  makeWrapper,
}:

let
  # To update version:
  # 1. Run: curl -fsSL https://cursor.com/install | head -20
  #    to find the latest version string (e.g., "2026.01.28-fd13201")
  # 2. Change version below
  # 3. Set all hashes to lib.fakeSha256
  # 4. Run rebuild - Nix will show correct hashes in the error
  # 5. Copy the correct hashes here
  version = "2026.01.28-fd13201";

  # Download URL pattern: https://downloads.cursor.com/lab/{version}/{os}/{arch}/agent-cli-package.tar.gz
  os = if stdenv.isDarwin then "darwin" else "linux";
  arch = if stdenv.isAarch64 then "arm64" else "x64";

  hashes = {
    "darwin-arm64" = "sha256-R5kEfd84IaUXuN+PIzpGD1NGPzD6xxM9NAXAAt6d0N8=";
    "darwin-x64" = "sha256-G23LC7Sl1GjfaECndSuyCxHK4drkJKG3B1U2k5SAHJA=";
    "linux-x64" = "sha256-Nj6q11iaa++b5stsEu1eBRAYUFRPft84XcHuTCZL5D0=";
    "linux-arm64" = "sha256-6oajVZw599vzy2c1olEzoIlqbmfZRK1atb85fiR72y0=";
  };

  platformKey = "${os}-${arch}";
in
stdenv.mkDerivation {
  pname = "cursor-cli";
  inherit version;

  src = fetchurl {
    url = "https://downloads.cursor.com/lab/${version}/${os}/${arch}/agent-cli-package.tar.gz";
    sha256 = hashes.${platformKey} or lib.fakeSha256;
  };

  sourceRoot = ".";
  dontBuild = true;
  dontStrip = true; # Bundled binaries (node, rg) are pre-stripped

  nativeBuildInputs = [ makeWrapper ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    # Install all files to lib directory (JS chunks, node binary, native modules)
    mkdir -p $out/lib/cursor-cli $out/bin
    cp -r . $out/lib/cursor-cli/

    # Make binaries executable
    chmod +x $out/lib/cursor-cli/cursor-agent
    chmod +x $out/lib/cursor-cli/node
    chmod +x $out/lib/cursor-cli/rg
    chmod +x $out/lib/cursor-cli/cursorsandbox
    chmod +x $out/lib/cursor-cli/spawn-helper

    # Create bin symlinks
    ln -s $out/lib/cursor-cli/cursor-agent $out/bin/cursor-agent
    ln -s $out/lib/cursor-cli/cursor-agent $out/bin/agent

    runHook postInstall
  '';

  meta = with lib; {
    description = "Cursor AI CLI agent for terminal-based development";
    homepage = "https://cursor.com/cli";
    license = licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    mainProgram = "cursor-agent";
  };
}
