{
  lib,
  stdenv,
  python311,
  uv,
  cacert,
  makeWrapper,
  glib,
  libglvnd,
  libSM,
  libICE,
  libX11,
  libXext,
  libXrender,
  zlib,
}:

let
  version = "4.2.9";

  # cu121 is the last CUDA wheel line that still includes Pascal (sm_61).
  py = python311.withPackages (ps: [ ps.pip ]);

  wheels = stdenv.mkDerivation {
    pname = "invokeai-wheels";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [
      py
      cacert
    ];

    dontFixup = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-IWbxw1rXeH52nRICpetXbL+1HHH+OsGkHgg7/sW4soc=";

    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      pip download \
        --no-cache-dir \
        --dest "$out" \
        --extra-index-url https://download.pytorch.org/whl/cu121 \
        'InvokeAI[xformers]==${version}' \
        'torch==2.2.2+cu121' \
        'torchvision==0.17.2+cu121' \
        'numpy==1.26.4' \
        'opencv-python==4.9.0.80' \
        'opencv-python-headless==4.9.0.80' \
        'opencv-contrib-python==4.9.0.80' \
        'setuptools' \
        'wheel'
      runHook postInstall
    '';
  };

  libPath = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    zlib
    glib
    libglvnd
    libSM
    libICE
    libX11
    libXext
    libXrender
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "invokeai";
  inherit version;

  dontUnpack = true;
  dontStrip = "1";
  dontPatchELF = "1";

  nativeBuildInputs = [
    uv
    python311
    makeWrapper
    stdenv.cc
  ];

  installPhase = ''
    runHook preInstall
    export HOME="$TMPDIR"
    export UV_CACHE_DIR="$TMPDIR/uv-cache"
    export UV_PYTHON_DOWNLOADS=never
    export UV_NO_MANAGED_PYTHON=1
    mkdir -p "$UV_CACHE_DIR"
    uv venv --python ${python311}/bin/python "$out"
    uv pip install \
      --python "$out/bin/python" \
      --offline \
      --no-index \
      --find-links ${wheels} \
      --no-cache \
      setuptools wheel
    uv pip install \
      --python "$out/bin/python" \
      --offline \
      --no-index \
      --no-build-isolation \
      --find-links ${wheels} \
      --no-cache \
      'InvokeAI[xformers]==${finalAttrs.version}' \
      'torch==2.2.2+cu121' \
      'torchvision==0.17.2+cu121' \
      'numpy==1.26.4' \
      'opencv-python==4.9.0.80' \
      'opencv-python-headless==4.9.0.80' \
      'opencv-contrib-python==4.9.0.80'

    for bin in "$out"/bin/invokeai*; do
      wrapProgram "$bin" \
        --prefix LD_LIBRARY_PATH : "${libPath}:/run/opengl-driver/lib" \
        --run 'export INVOKEAI_ROOT="''${INVOKEAI_ROOT:-$HOME/invokeai}"' \
        --run 'export INVOKEAI_HOST="''${INVOKEAI_HOST:-0.0.0.0}"' \
        --run 'export INVOKEAI_PORT="''${INVOKEAI_PORT:-9090}"'
    done
    runHook postInstall
  '';

  preFixup = ''
    dontStrip=1
    dontPatchELF=1
  '';

  meta = {
    description = "InvokeAI ${version} (torch 2.2.2+cu121)";
    mainProgram = "invokeai-web";
    platforms = [ "x86_64-linux" ];
  };
})
