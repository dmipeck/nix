# Grok Bot desktop agent — official Linux amd64 .deb, wrapped for NixOS.
# Adapted from https://github.com/jordangarrison/grok-bot-flake (not in
# nixpkgs yet; PR #558990 is still draft). No well-supported community
# nixpkgs package existed when this was vendored.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeShellWrapper,
  wrapGAppsHook3,

  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  libx11,
  libxcb,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxkbcommon,
  libxrandr,
  libxrender,
  libxscrnsaver,
  libxshmfence,
  libxtst,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  wayland,
  xdg-utils,
}:

let
  # Download URL embeds upstream product namespace + build id alongside the
  # version. Bump all three together when updating.
  downloadBase = "https://downloads.cursor.com/grokbot/stable";
  buildId = "c1e7d7a46549956d25f53e9c0b9f59666e03aa3a";

  # Shared libraries the bundled Chromium dlopen()s at runtime — autoPatchelf
  # cannot discover them from DT_NEEDED alone.
  runtimeLibs = [
    libglvnd
    libGL
    libgbm
    libdrm
    vulkan-loader
    wayland
    libxkbcommon
    libpulseaudio
    libsecret
    libnotify
    (lib.getLib systemd)
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "grok-bot";
  version = "0.47.0";
  # Upstream has used both Grok_Bot_<ver>.deb and grok-bot_<ver>_amd64.deb.
  debFile = "grok-bot_${finalAttrs.version}_amd64.deb";

  src = fetchurl {
    url = "${downloadBase}/${buildId}/linux/x64/${finalAttrs.debFile}";
    hash = "sha256-EcoPUaU1uXr1GjUq35wPns0uGwQwpprpRRtoinoGWAg=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeShellWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libuuid
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    libx11
    libxcb
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
  ]
  ++ runtimeLibs;

  runtimeDependencies = runtimeLibs;

  dontStrip = true;
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/grok-bot"
    cp -r "opt/Grok Bot/." "$out/share/grok-bot/"

    # chrome-sandbox needs setuid root; Nix store cannot. Chromium falls back
    # to the user-namespace sandbox (enabled on NixOS).
    rm -f "$out/share/grok-bot/chrome-sandbox"

    foundIcon=""
    for extension in png svg; do
      for icon in usr/share/icons/hicolor/*/apps/{sand,grok-bot}."$extension"; do
        [ -f "$icon" ] || continue
        relativeIcon="''${icon#usr/share/icons/hicolor/}"
        iconSize="''${relativeIcon%%/*}"
        install -Dm644 "$icon" \
          "$out/share/icons/hicolor/$iconSize/apps/grok-bot.$extension"
        foundIcon=1
      done
    done
    if [ -z "$foundIcon" ]; then
      echo "error: no grok-bot/sand hicolor icon found in the .deb" >&2
      exit 1
    fi

    if [ -f usr/share/applications/grok-bot.desktop ]; then
      desktop=usr/share/applications/grok-bot.desktop
    else
      desktop=usr/share/applications/sand.desktop
    fi
    install -Dm644 "$desktop" "$out/share/applications/grok-bot.desktop"

    if ! grep -q '^Exec=' "$out/share/applications/grok-bot.desktop"; then
      echo "error: upstream desktop file has no Exec entry" >&2
      exit 1
    fi
    sed -i \
      -e "s|^Exec=.*|Exec=$out/bin/grok-bot %U|" \
      -e 's/^Icon=.*/Icon=grok-bot/' \
      "$out/share/applications/grok-bot.desktop"

    runHook postInstall
  '';

  preFixup = ''
    # makeShellWrapper (not binary wrapper): conditional ozone flags need shell
    # expansion. CHROME_DESKTOP is how Electron's setAsDefaultProtocolClient()
    # picks the .desktop id for sand:// URL registration.
    #
    # --no-sandbox: upstream's Electron crash-loops sandboxed webview
    # renderers (FATAL:platform_shared_memory_region_posix.cc). Upstream already
    # launches the main renderer / GPU / utilities unsandboxed; the webview was
    # the only sandboxed process and only ever crashed.
    if [ -x "$out/share/grok-bot/grok-bot" ]; then
      upstreamExecutable="$out/share/grok-bot/grok-bot"
    else
      upstreamExecutable="$out/share/grok-bot/sand"
    fi

    makeShellWrapper "$upstreamExecutable" "$out/bin/grok-bot" \
      "''${gappsWrapperArgs[@]}" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --set-default CHROME_DESKTOP grok-bot.desktop \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    # Historical binary name used by older releases and sand:// URLs.
    ln -s "$out/bin/grok-bot" "$out/bin/sand"
  '';

  meta = {
    description = "Grok Bot desktop agent";
    homepage = "https://x.ai/news/introducing-grok-bot";
    downloadPage = "https://cursor.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "grok-bot";
  };
})
