{ lib
, stdenv
, python311
, makeWrapper
, libsndfile
, ffmpeg-headless
, fetchFromGitHub
, zlib
, glibc
, zstd
, fetchurl
, ...
}:

let
  pname = "chatterbox-tts-server";
  version = "2.0.0";

  python = python311;
  sitePkgs = "lib/${python.libPrefix}/site-packages";
  runtimeLibs = lib.makeLibraryPath [ stdenv.cc.cc.lib libsndfile zlib glibc zstd ];

  src = fetchFromGitHub {
    owner = "devnen";
    repo = "Chatterbox-TTS-Server";
    rev = "915ae289340e10c6047f27f47e22eae9bf350c32";
    hash = "sha256-bdf6UoqUxdNdEARQAyI2orKbmSbwtjCK4XdPXD+0zUg=";
  };

  chatterboxSrc = fetchFromGitHub {
    owner = "resemble-ai";
    repo = "chatterbox";
    rev = "65b18437192794391a0308a8f705b1e33e633948";
    hash = "sha256-PpoBKGI8X9BQxl2y3Jyg5lebEgXzHfMCIAxufviZaS4=";
  };

  requirementsLock = builtins.readFile ./requirements-lock.txt;

  # Protobuf wheel — onnx needs >=4.25 but descript-audiotools pins <3.20 in FOD
  protobufWheel = fetchurl {
    url = "https://files.pythonhosted.org/packages/12/fb/a586e0c973c95502e054ac5f81f88394f24ccc7982dac19c515acd9e2c93/protobuf-5.29.4-py3-none-any.whl";
    hash = "sha256:3fde11b505e1597f71b875ef2fc52062b6a9740e5f7c8997ce878b6009145862";
  };

  # Phase 1: FOD — download and install pip packages (network allowed, no $out refs)
  deps = stdenv.mkDerivation {
    name = "${pname}-deps-${version}";
    inherit src;

    outputHashMode = "recursive";
    outputHash = "sha256-rmos5vO8EGSQ50H8EQHY+SW9o2cmJk98XhfV+W0guU0=";

    buildInputs = [ python libsndfile ffmpeg-headless zlib glibc ];

    PIP_REQUIRE_VIRTUALENV = "false";
    PIP_NO_INPUT = "1";
    PYTHONDONTWRITEBYTECODE = "1";
    SOURCE_DATE_EPOCH = "1";

    SERVER_SRC = src;
    CHATTERBOX_SRC = chatterboxSrc;

    buildPhase = ''
      runHook preBuild

      ${python}/bin/python -m venv /tmp/pip-venv
      PIP=/tmp/pip-venv/bin/pip

      mkdir -p "$out/share/chatterbox-tts"
      cp -r "$SERVER_SRC"/* "$out/share/chatterbox-tts/"
      chmod -R u+w "$out/share/chatterbox-tts/"

      cp -r "$CHATTERBOX_SRC" /build/chatterbox
      chmod -R u+w /build/chatterbox

      $PIP install --no-cache-dir --no-build-isolation \
        --target "$out/${sitePkgs}" \
        --index-url https://download.pytorch.org/whl/cpu \
        torch==2.6.0+cpu torchaudio==2.6.0+cpu torchvision==0.21.0+cpu

      cat > /tmp/requirements-all.txt << 'LOCKEOF'
${requirementsLock}
LOCKEOF
      grep -v '^torch\b\|^torchaudio\b\|^torchvision\b' /tmp/requirements-all.txt > /tmp/requirements-no-torch.txt
      $PIP install --no-cache-dir --no-build-isolation \
        --target "$out/${sitePkgs}" \
        -r /tmp/requirements-no-torch.txt

      $PIP install --no-cache-dir --no-build-isolation \
        --no-deps \
        --target "$out/${sitePkgs}" \
        /build/chatterbox

      find "$out" -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
      find "$out" -name '*.pyc' -delete 2>/dev/null || true
      find "$out" -path '*/RECORD' -delete 2>/dev/null || true
      find "$out" -path '*/INSTALLER' -delete 2>/dev/null || true
      find "$out" -path '*/direct_url.json' -delete 2>/dev/null || true
      find "$out" -path '*/direct_url.url' -delete 2>/dev/null || true
      find "$out" -name 'REQUESTED' -delete 2>/dev/null || true

      rm -rf "$out/bin" 2>/dev/null || true
      find "$out" -type f -exec chmod 644 {} +
      find "$out" -type d -exec chmod 755 {} +

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      runHook postInstall
    '';
  };
in
# Phase 2: non-FOD — wrap with executable (can reference $out freely)
stdenv.mkDerivation {
  inherit pname version;

  src = deps;

  buildInputs = [ python makeWrapper libsndfile ffmpeg-headless ];

  buildPhase = ''
    runHook preBuild
    mkdir -p $out
    cp -r "$src"/* "$out/"
    chmod -R u+w "$out"
    mkdir -p $out/bin
  '';

  installPhase = ''
    runHook preInstall
    # Upgrade protobuf to fix onnx compatibility (FOD has 3.19.6 due to dep pin)
    ${python}/bin/python -m zipfile -e ${protobufWheel} "$out/${sitePkgs}"
    chmod -R u+w "$out/${sitePkgs}/google"

    # Collect bundled .libs dirs from manylinux wheels (for LD_LIBRARY_PATH)
    mkdir -p "$out/share/chatterbox-tts"
    find "$out/${sitePkgs}" -maxdepth 2 -name '*.libs' -type d > "$out/share/chatterbox-tts/.bundled-libs" 2>/dev/null || true
    BUNDLED=$(tr '\n' ':' < "$out/share/chatterbox-tts/.bundled-libs" 2>/dev/null || true)
    makeWrapper ${python}/bin/python $out/bin/chatterbox-tts \
      --prefix PYTHONPATH : "$out/${sitePkgs}" \
      --prefix PYTHONPATH : "$out/share/chatterbox-tts" \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]} \
      --prefix LD_LIBRARY_PATH : "${runtimeLibs}" \
      --prefix LD_LIBRARY_PATH : "$BUNDLED" \
      --set-default PYTHONUNBUFFERED "1" \
      --add-flags "-m uvicorn server:app"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Chatterbox TTS Server — OpenAI-compatible TTS API with Web UI, voice cloning, and multi-engine support";
    homepage = "https://github.com/devnen/Chatterbox-TTS-Server";
    license = licenses.mit;
    mainProgram = "chatterbox-tts";
    platforms = platforms.linux;
    maintainers = [ ];
  };
}