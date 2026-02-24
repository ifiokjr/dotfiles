{
  stdenv,
  fetchurl,
  lib,
  # macOS
  undmg ? null,
  # Linux
  bintools ? null,
  patchelf ? null,
  makeWrapper ? null,
  xdg-utils ? null,
  alsa-lib ? null,
  at-spi2-atk ? null,
  at-spi2-core ? null,
  cairo ? null,
  cups ? null,
  dbus ? null,
  expat ? null,
  fontconfig ? null,
  freetype ? null,
  glib ? null,
  gtk3 ? null,
  libdrm ? null,
  libgbm ? null,
  libglvnd ? null,
  libxkbcommon ? null,
  mesa ? null,
  nspr ? null,
  nss ? null,
  pango ? null,
  pipewire ? null,
  systemd ? null,
  vulkan-loader ? null,
  wayland ? null,
  xorg ? null,
  adwaita-icon-theme ? null,
  gsettings-desktop-schemas ? null,
}:

let
  # To update:
  # 1. Set hash(es) to lib.fakeHash
  # 2. Run rebuild - Nix will show the correct hash in the error
  # 3. Copy the correct hash here
  # Note: Google Chrome uses rolling URLs so hashes change with each release
  sources = {
    "x86_64-darwin" = {
      url = "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg";
      hash = "sha256-tEZQk64nIU9cgvKwOwBIn4pLv0mTT9vSgmqLEYqCyAg=";
    };
    "aarch64-darwin" = {
      url = "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg";
      # Apple Silicon uses the same universal DMG payload as x86_64 on macOS.
      hash = "sha256-tEZQk64nIU9cgvKwOwBIn4pLv0mTT9vSgmqLEYqCyAg=";
    };
    "x86_64-linux" = {
      url = "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb";
      hash = "sha256-lGMopGtpLp3g0PVIfRIACNP6yRarzQDIsuctNbiqCCo=";
    };
  };

  runtimeLibs = lib.optionals stdenv.isLinux [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pipewire
    systemd
    vulkan-loader
    wayland
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
  ];

  rpath = lib.makeLibraryPath runtimeLibs;
in
stdenv.mkDerivation {
  pname = "google-chrome";
  version = "latest";

  src = fetchurl (sources.${stdenv.system} or (throw "Unsupported system: ${stdenv.system}"));

  nativeBuildInputs =
    lib.optionals stdenv.isDarwin [ undmg ]
    ++ lib.optionals stdenv.isLinux [
      patchelf
      makeWrapper
    ];

  buildInputs = lib.optionals stdenv.isLinux [
    adwaita-icon-theme
    glib
    gtk3
    gsettings-desktop-schemas
  ];

  sourceRoot = lib.optionalString stdenv.isDarwin ".";

  # Common flags
  dontConfigure = true;
  dontBuild = true;
  dontFixup = stdenv.isDarwin;
  dontPatch = stdenv.isDarwin;

  unpackPhase =
    if stdenv.isLinux then
      ''
        runHook preUnpack
        ${lib.getExe' bintools "ar"} x $src
        tar xf data.tar.xz
        runHook postUnpack
      ''
    else
      null;

  installPhase =
    if stdenv.isDarwin then
      ''
        runHook preInstall
        mkdir -p $out/Applications
        cp -r "Google Chrome.app" $out/Applications/
        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        exe=$out/bin/google-chrome-stable
        mkdir -p $out/bin $out/share

        cp -a opt/* $out/share
        cp -a usr/share/* $out/share

        # Replace bundled vulkan-loader
        rm -f $out/share/google/chrome/libvulkan.so.1
        ln -s "${lib.getLib vulkan-loader}/lib/libvulkan.so.1" \
          "$out/share/google/chrome/libvulkan.so.1"

        # Patch ELF binaries
        for elf in $out/share/google/chrome/{chrome,chrome-sandbox,chrome_crashpad_handler}; do
          if [ -f "$elf" ]; then
            patchelf --set-rpath "${rpath}" "$elf"
            patchelf --set-interpreter "${bintools.dynamicLinker}" "$elf"
          fi
        done

        # Patch shared libraries
        for lib_file in $out/share/google/chrome/lib*.so*; do
          if [ -f "$lib_file" ]; then
            patchelf --set-rpath "${rpath}" "$lib_file" 2>/dev/null || true
          fi
        done

        # Update desktop files
        substituteInPlace $out/share/applications/com.google.Chrome.desktop \
          --replace-fail /usr/bin/google-chrome-stable $exe

        # Create wrapper
        makeWrapper "$out/share/google/chrome/google-chrome" "$exe" \
          --prefix LD_LIBRARY_PATH : "${rpath}" \
          --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}" \
          --prefix XDG_DATA_DIRS : "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
          --add-flags "--simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT'"

        runHook postInstall
      '';

  meta = with lib; {
    description = "Google Chrome web browser";
    homepage = "https://www.google.com/chrome/";
    license = licenses.unfree;
    platforms = [
      "x86_64-darwin"
      "aarch64-darwin"
      "x86_64-linux"
    ];
    maintainers = [ ];
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
  };
}
