{
  stdenv,
  fetchurl,
  lib,
  autoPatchelfHook,
  undmg,
  dpkg,
  alsa-lib,
  gtk3,
  xdotool,
  libxkbcommon,
  libappindicator-gtk3,
  libepoxy,
  pango,
  gdk-pixbuf,
  libGL,
  xorg,
  libpulseaudio,
  makeWrapper,
}:

# RustDesk is not available in nixpkgs for macOS. This package fetches
# pre-built binaries from GitHub releases for all platforms.

let
  # To update version:
  # 1. Change version number below
  # 2. Set all hashes to lib.fakeSha256
  # 3. Run rebuild - Nix will show the correct hashes in the error
  # 4. Copy the correct hashes here
  version = "1.4.5";

  arch = if stdenv.isAarch64 then "aarch64" else "x86_64";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-aarch64.dmg";
      hash = "sha256-5UjhlNgK1E9m964zs9KHmmMAIBraoNvfbdK9NZTj6RI=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-x86_64.dmg";
      hash = "sha256-kf6GvtmgYHkG6tTTi89Sl8g8QEZDNCRWc4sDb5psWNQ=";
    };
    "x86_64-linux" = {
      url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-x86_64.deb";
      hash = "sha256-YRfqLC9YhYML/2S2tpWyWWomE9w1MBU58ZrlJ0cYHIM=";
    };
    "aarch64-linux" = {
      url = "https://github.com/rustdesk/rustdesk/releases/download/${version}/rustdesk-${version}-aarch64.deb";
      hash = "sha256-u3x4BDhlrBaw2EPeJcwckWvf8Zor0bLDT31GxieCdoI=";
    };
  };

  platformKey = "${arch}-${if stdenv.isDarwin then "darwin" else "linux"}";
  src = fetchurl (sources.${platformKey} or (throw "Unsupported platform: ${platformKey}"));
in
stdenv.mkDerivation {
  pname = "rustdesk";
  inherit version src;

  dontBuild = true;
  dontStrip = true;
  dontFixup = stdenv.isDarwin;

  nativeBuildInputs =
    lib.optionals stdenv.isDarwin [ undmg ]
    ++ lib.optionals stdenv.isLinux [
      dpkg
      autoPatchelfHook
      makeWrapper
    ];

  buildInputs = lib.optionals stdenv.isLinux [
    alsa-lib
    gtk3
    xdotool
    libxkbcommon
    libappindicator-gtk3
    libepoxy
    pango
    gdk-pixbuf
    libGL
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libXScrnSaver
    libpulseaudio
    stdenv.cc.cc.lib
  ];

  unpackPhase =
    if stdenv.isDarwin then
      ''
        undmg $src
      ''
    else
      ''
        dpkg-deb -x $src .
      '';

  installPhase =
    if stdenv.isDarwin then
      ''
        runHook preInstall

        mkdir -p $out/Applications
        cp -r RustDesk.app $out/Applications/
        mkdir -p $out/bin
        ln -s "$out/Applications/RustDesk.app/Contents/MacOS/RustDesk" $out/bin/rustdesk

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out
        cp -r usr/* $out/

        runHook postInstall
      '';

  meta = with lib; {
    description = "Open-source remote desktop software, written in Rust";
    homepage = "https://rustdesk.com/";
    license = licenses.agpl3Plus;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
    mainProgram = "rustdesk";
  };
}
