{ lib
, stdenv
, fetchFromGitHub
, cmake
, ninja
, python3
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, nix-update-script
, pkgs
, pkgs-stable ? null
}:

let
  pname = "o3de";
  version = "2605.0";

  src = fetchFromGitHub {
    owner = "o3de";
    repo = "o3de";
    rev = "2605.0";
    sha256 = "0js7xbvbqihllajggj2mgvr9rkc2dwxp9gsdk9nbjgk7jwhrkcmn";
  };

  # Google cityhash — needed by AzCore for TypeHash32/64.
  # Bundled locally because no nixpkgs package exists and GitHub tags are missing.
  cityhashSrc = ./cityhash;

  # Use python310 from nixpkgs-stable when available, fall back to unstable python3.
  # pkgs-stable is provided by overlays/default.nix; auto-wired callPackage omits it.
  py = if pkgs-stable != null then pkgs-stable.python310 else python3;
  pyVersion = lib.versions.majorMinor py.version;
  pyLibName = "libpython${pyVersion}.so.1.0";
  pySitePkgs = "lib/python${pyVersion}/site-packages";

  # CMake overlay that pre-defines 3rdParty::* targets from nixpkgs packages,
  # causing O3DE to skip the CDN downloads.  Injected via CMAKE_PROJECT_INCLUDE.
  nixpkgsOverlay = ./NixpkgsPackages.cmake;

  pythonEnv = py.withPackages (ps: with ps; [
    jinja2
    pyyaml
    setuptools
    wheel
  ]);

  # nixpkgs packages mapped by NixpkgsPackages.cmake to 3rdParty::* targets.
  # These are in addition to the direct build inputs for O3DE itself.
  overlayPackages = with pkgs; [
    zlib
    openssl
    libpng
    expat
    freetype
    zstd
    lz4
    sqlite
    rapidjson
    xxhash
    libtiff
    lua
    openexr
    imath
    spirv-cross
    glslang
    assimp
    gtest
    python3Packages.pybind11
    meshoptimizer
    mcpp
    openmesh
    miniaudio
    libogg
    libvorbis
    directx-shader-compiler
    astc-encoder
    openimageio
    rapidxml
    lua5_4
  ] ++ lib.optional (pkgs ? openimageio) pkgs.openimageio.dev;

  allBuildInputs = with pkgs; [
    cmake
    ninja
    pkg-config
    pythonEnv
    vulkan-headers
    vulkan-loader
    glslang
    spirv-tools
    rapidjson
    libxml2
    zlib
    zstd
    xorg.libX11
    xorg.libXau
    xorg.libxcb
    libxcb
    xorg.xcbutil
    xorg.xcbutilwm
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    libXi
    libXrandr
    libXcursor
    libXinerama
    libXext
    libXfixes
    libXrender
    libXcomposite
    libXdamage
    libXtst
    libpthreadstubs
    libxkbcommon
    wayland
    wayland-protocols
    mesa
    libGL
    dbus
    fontconfig
    freetype
    libunwind
    alsa-lib
    pulseaudio
    pipewire
    libsamplerate
    libsndfile
  ] ++ overlayPackages;

  qtInputs = with pkgs.qt6; [
    qtbase
    qtsvg
    qttools
    qtdeclarative
    qtwayland
    qtimageformats
    qtshadertools
  ];
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  dontWrapQtApps = true;

  nativeBuildInputs = with pkgs; [
    cmake
    ninja
    pkg-config
    py
    git
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = allBuildInputs ++ qtInputs ++ [
    pythonEnv
  ];

  patchPhase = ''
    # RapidXML ships as .hpp in nixpkgs but O3DE includes <rapidxml/rapidxml.h> — fix includes
    for rf in Code/Framework/AzCore/AzCore/XML/rapidxml*.h; do
      sed -i 's|<rapidxml/\(rapidxml[^>]*\)\.h>|<rapidxml/\1.hpp>|g' "$rf"
    done
    # GCC 15 two-phase lookup: functions in rapidxml_print.hpp used before declared.
    # Copy nixpkgs rapidxml headers, add forward decls, shadow nixpkgs with our copy.
    mkdir -p Code/RapidXML
    cp -r ${pkgs.rapidxml}/include/rapidxml Code/RapidXML/rapidxml
    chmod -R u+w Code/RapidXML
    # Patch nixpkgs rapidxml for O3DE compatibility:
    # 1. RAPIDXML_NO_EXCEPTIONS support (store errors in document, not throw)
    # 2. isError() / getError() / clearError() on xml_document
    # 3. parse_no_data_nodes flag
    # 4. bool-returning parse() overload
    # 5. GCC 15+ forward declarations for rapidxml_print.hpp
    ${py}/bin/python3 ${./patch-rapidxml-o3de.py} Code/RapidXML/rapidxml

    # Patch all AzCore rapixml wrappers to define RAPIDXML_NO_EXCEPTIONS
    # when exceptions are disabled in the O3DE build system.
    for _rapidxml_wrapper in Code/Framework/AzCore/AzCore/XML/rapidxml.h Code/Framework/AzCore/AzCore/XML/rapidxml_print.h; do
      substituteInPlace "$_rapidxml_wrapper" \
        --replace-fail '#define RAPIDXML_SKIP_AZCORE_ERROR' \
          '#define RAPIDXML_NO_EXCEPTIONS

#define RAPIDXML_SKIP_AZCORE_ERROR'
    done

    # Patch O3DE callers that use parse() -> bool return (not supported by
    # standard rapidxml). Our patch provides try_parse() for this.
    substituteInPlace Gems/AudioSystem/Code/Include/Engine/AudioFileUtils.h \
      --replace-fail '.parse<AZ::rapidxml::parse_no_data_nodes>(' '.try_parse<AZ::rapidxml::parse_no_data_nodes>('
    substituteInPlace Gems/LmbrCentral/Code/Source/Builders/CopyDependencyBuilder/XmlFormattedAssetBuilderWorker.cpp \
      --replace-fail '.parse<AZ::rapidxml::parse_no_data_nodes>(' '.try_parse<AZ::rapidxml::parse_no_data_nodes>('
    substituteInPlace Code/Tools/AssetProcessor/AssetBuilderSDK/AssetBuilderSDK/AssetBuilderSDK.cpp \
      --replace-fail '->parse<AZ::rapidxml::parse_no_data_nodes>(' '->try_parse<AZ::rapidxml::parse_no_data_nodes>('
    # Verify our patched copies have O3DE extensions
    test -f Code/RapidXML/rapidxml/rapidxml_print.hpp || { echo "ERROR: patched copy missing"; exit 1; }
    grep -q 'isError' Code/RapidXML/rapidxml/rapidxml.hpp || { echo "ERROR: isError not in patched rapidxml.hpp"; exit 1; }
    grep -q 'Forward declarations' Code/RapidXML/rapidxml/rapidxml_print.hpp || { echo "ERROR: forward decls not in patched rapidxml_print.hpp"; exit 1; }
    # Add our patched rapidxml to include path BEFORE nixpkgs copy
    sed -i '1iinclude_directories(BEFORE "''${CMAKE_CURRENT_SOURCE_DIR}/RapidXML")' Code/CMakeLists.txt
    # Lua headers in nixpkgs are at <lua.h> not <Lua/lua.h> — fix all files
    for f in \
      Code/Framework/AzCore/AzCore/Script/lua/lua.h \
      Code/Framework/AzCore/AzCore/Script/ScriptContext.cpp \
      Code/Framework/AzCore/AzCore/Script/ScriptContextDebug.cpp \
      Code/Framework/AzCore/AzCore/Script/ScriptPropertyTable.cpp \
      Code/Framework/AzFramework/AzFramework/Script/ScriptComponent.cpp \
      Code/Framework/AzToolsFramework/AzToolsFramework/ToolsComponents/ScriptEditorComponent.cpp \
      Code/Framework/AzToolsFramework/Tests/Script/ScriptComponentTests.cpp; do
      test -f "$f" && sed -i 's|<Lua/\(l[^>]*\)>|<\1>|g' "$f" || true
    done
    # Lua internal headers (lobject.h etc.) not in nixpkgs public API
    mkdir -p Code/LuaInternals
    tar xzf ${pkgs.lua5_4.src} -C Code/LuaInternals --strip-components=2 --wildcards 'lua-5.4.7/src/l*.h'
    # Prepend include dir before add_subdirectory calls in Code/CMakeLists.txt
    sed -i '1iinclude_directories("''${CMAKE_CURRENT_SOURCE_DIR}/LuaInternals")' Code/CMakeLists.txt
    ${py}/bin/python3 ${./fix-requirements.py} python/requirements.txt
    # Don't fail configure when LY_PACKAGE_SERVER_URLS is empty (no CDN access)
    substituteInPlace cmake/3rdPartyPackages.cmake \
      --replace-fail 'message(SEND_ERROR "ly_package:' 'message(STATUS "ly_package:'
    # Always use our pre-existing venv — never recreate it.
    substituteInPlace cmake/LYPython.cmake \
      --replace-fail 'set(CREATE_NEW_VENV TRUE)' 'set(CREATE_NEW_VENV FALSE)'
    # Skip pip install of requirements.txt (packages provided by nixpkgs).
    substituteInPlace cmake/LYPython.cmake \
      --replace-fail 'message(FATAL_ERROR "The above failure will cause errors later - stopping now.' 'message(WARNING "The above failure will cause errors later - continuing anyway.'
    # CityHash — needed by AzCore for TypeHash32/64 (CityHash32/CityHash64).
    # Google's cityhash is not packaged in nixpkgs, so we bundle the source.
    # Copy city.h to the AzCore include path so #include <city.h> resolves.
    cp ${cityhashSrc}/city.h Code/Framework/AzCore/
    cp ${cityhashSrc}/config.h Code/Framework/AzCore/
    # Compile city.cc into a static library for AzCore linking
    g++ -std=c++20 -fPIC -fno-exceptions -I Code/Framework/AzCore -c ${cityhashSrc}/city.cc -o Code/Framework/AzCore/city.o
    ar rcs Code/Framework/AzCore/libcityhash.a Code/Framework/AzCore/city.o
    # Show AutoGen full error diagnostics in cmake log
    substituteInPlace cmake/LyAutoGen.cmake \
      --replace-fail 'if(NOT AUTOGEN_RESULT EQUAL 0)
            message(FATAL_ERROR
                "AutoGen expansion rules failed for target: ' \
        'message(STATUS "AZ_AUTOGEN_START: ''${ly_add_autogen_NAME}
AUTOGEN_RESULT=''${AUTOGEN_RESULT}
AUTOGEN_ERROR=''${AUTOGEN_ERROR}
AUTOGEN_OUTPUTS=''${AUTOGEN_OUTPUTS}")
if(NOT AUTOGEN_RESULT EQUAL 0)
            message(FATAL_ERROR
                "AutoGen expansion rules failed for target: '
    # Suppress GCC 14+ -Wno-nonnull and -Wno-unused-variable via Python script
    # (substituteInPlace doesn't handle multi-line replacements well)
    ${py}/bin/python3 ${./patch-gcc-config.py}
  '';

  cmakeFlags = [
    "-G"
    "Ninja"
    "-DLY_CMAKE_TARGET=QtOrNative"
    "-DLY_UNITY_BUILD=OFF"
    "-DLY_PROJECTS_PATH=${placeholder "out"}/share/o3de/Projects"
    "-DLY_ENGINE_BINARY_DIR=${placeholder "out"}/bin"
    "-DLY_BUILD_EDITOR=ON"
    "-DLY_BUILD_ASSET_PROCESSOR=ON"
    "-DLY_BUILD_MATERIAL_CANVAS=ON"
    "-DLY_BUILD_TESTS=OFF"
    "-DLY_BUILD_DOCS=OFF"
    "-DCMAKE_SKIP_BUILD_RPATH=OFF"
    "-DCMAKE_BUILD_RPATH=${placeholder "out"}/lib"
    "-DCMAKE_INSTALL_RPATH=${placeholder "out"}/lib"
    "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
    "-DCMAKE_INSTALL_BINDIR=bin"
    "-DCMAKE_INSTALL_LIBDIR=lib"
    "-DCMAKE_INSTALL_INCLUDEDIR=include"
    "-DUSE_VK_LOADER=ON"
    "-DLY_DISABLE_TEST_MODULES=ON"
    # Disable CDN downloads; pre-resolve packages via NixpkgsPackages.cmake
    "-DLY_PACKAGE_SERVER_URLS="
    # Inject our nixpkgs CMake overlay early
    "-DCMAKE_PROJECT_INCLUDE=${nixpkgsOverlay}"
  ];

  preConfigure = ''
    patchShebangs scripts/ python/ cmake/
    # Suppress GCC 14+ -Werror compatibility issues via env var that cmake honors
    export CXXFLAGS="-Wno-nonnull -Wno-unused-variable"

    export HOME="$TMPDIR/o3de-home"
    export O3DE_SNAP=1
    mkdir -p "$HOME/.o3de"

    # Pre-populate O3DE Python package directory with python from nixpkgs.
    # O3DE's cmake expects python-3.10.13-rev2-linux (hardcoded in LYPython.cmake).
    # We create a symlink from the expected path to our actual python.
    O3DE_PY_PACKAGE_BASE="$HOME/.o3de/Python/packages"
    mkdir -p "$O3DE_PY_PACKAGE_BASE/python-3.10.13-rev2-linux/python/bin" \
             "$O3DE_PY_PACKAGE_BASE/python-3.10.13-rev2-linux/python/lib"
    ln -sf ${py}/bin/python3 "$O3DE_PY_PACKAGE_BASE/python-3.10.13-rev2-linux/python/bin/python"
    ln -sf ${py}/lib/${pyLibName} "$O3DE_PY_PACKAGE_BASE/python-3.10.13-rev2-linux/python/lib/${pyLibName}"
    # Also create under our actual pyVersion for compatibility
    mkdir -p "$O3DE_PY_PACKAGE_BASE/python-${pyVersion}-rev2-linux/python/bin" \
             "$O3DE_PY_PACKAGE_BASE/python-${pyVersion}-rev2-linux/python/lib"
    ln -sf ${py}/bin/python3 "$O3DE_PY_PACKAGE_BASE/python-${pyVersion}-rev2-linux/python/bin/python"
    ln -sf ${py}/lib/${pyLibName} "$O3DE_PY_PACKAGE_BASE/python-${pyVersion}-rev2-linux/python/lib/${pyLibName}"

    # Compute ENGINE_ID and create venv now so venv hash matches cmake
    ENGINE_ID=$(cmake -P cmake/CalculateEnginePathId.cmake "$PWD/" 2>&1)
    echo "preConfigure: ENGINE_ID=$ENGINE_ID"
    VENV_PATH="$HOME/.o3de/Python/venv/$ENGINE_ID"
    # Override LY_PYTHON_CMD to bypass python.sh (bad shebang, sandbox issues)
    # Use the nix store python directly — it has jinja2 in its native site-packages,
    # avoiding venv activation/PYTHONPATH issues in CMake's execute_process.
    cmakeFlagsArray+=("-DLY_PYTHON_CMD:FILEPATH=${py}/bin/python3")
    mkdir -p "$VENV_PATH/lib"
    ln -sf ${py}/lib/${pyLibName} "$VENV_PATH/lib/${pyLibName}"

    cat > "$HOME/.o3de/o3de_manifest.json" << MANIFEST
    {
      "engines": {
        "$(pwd)": {}
      },
      "projects": [],
      "templates": [],
      "restricted": [],
      "repos": []
    }
    MANIFEST

    # Create the venv ourselves (same way O3DE would)
    O3DE_PY="${py}/bin/python"
    "$O3DE_PY" -m venv "$VENV_PATH" --without-pip --clear 2>/dev/null

    # Install pip into the venv
    "$VENV_PATH/bin/python" -m ensurepip --upgrade --default-pip 2>/dev/null

    # Install all requirements from the nixpkgs pythonEnv
    "$VENV_PATH/bin/python" -m pip install --no-cache-dir --quiet \
      atomicwrites attrs boto3 botocore certifi chardet charset-normalizer \
      colorama docutils easyprocess exceptiongroup gitdb smmap gitpython idna \
      imageio importlib-metadata jmespath MarkupSafe more-itertools numpy \
      packaging pillow pluggy progressbar2 psutil pyparsing pyscreenshot \
      pytest pytest-mock pytest-timeout python-dateutil python-utils requests \
      s3transfer scipy six urllib3 wcwidth zipp toml iniconfig resolvelib \
      puremagic jinja2 pyyaml setuptools wheel \
      --disable-pip-version-check --no-warn-script-location 2>&1 | tail -3 || true

    # Copy nixpkgs site-packages into the venv so Jinja2 is available
    # for AutoGen (no network in sandbox).  Ignore failures.
    VENV_SITE="$VENV_PATH/${pySitePkgs}"
    rm -rf "$VENV_SITE"
    mkdir -p "$VENV_SITE"
    ln -sf "${py}/${pySitePkgs}"/* "$VENV_SITE/" 2>/dev/null || true
    "$VENV_PATH/bin/python" -c "import jinja2; print('jinja2 ok')" 2>&1 || echo "WARNING: jinja2 not in venv, AutoGen will fail"

    # Create the hash file (no trailing newline — cmake file(READ) includes it and breaks STREQUAL)
    printf "a7832f9170a3ac93fbe678e9b3d99a977daa03bb667d25885967e8b4977b86f8" > "$VENV_PATH/.hash"

    # Create stamps for all pip steps O3DE runs during configure
    mkdir -p "$VENV_PATH/requirements_files"
    touch "$VENV_PATH/requirements_files/default_requirements.stamp"
    mkdir -p "$VENV_PATH/packages/pip_installs"
    touch "$VENV_PATH/packages/pip_installs/ly-test-tools.stamp"
    touch "$VENV_PATH/packages/pip_installs/ly-remote-console.stamp"
    touch "$VENV_PATH/packages/pip_installs/editor-python-test-tools.stamp"
    touch "$VENV_PATH/packages/pip_installs/o3de.stamp"
    touch "$VENV_PATH/packages/pip_installs/atom_rpi_tools.stamp"
    # Gem-specific requirement stamps
    touch "$VENV_PATH/requirements_files/DccScriptingInterface.stamp"

    # Copy overlay into build dir and patch it, then override the cmake flag.
    # CMAKE_PROJECT_INCLUDE still points to the nix store original, so we
    # need to repoint it to our patched copy.
    cp ${nixpkgsOverlay} NixpkgsPackages.cmake
    chmod +w NixpkgsPackages.cmake
    # Fix Lua overlay to use Lua 5.4 instead of Lua 5.2
    ${py}/bin/python3 ${./patch-lua-overlay.py} NixpkgsPackages.cmake
    # Override CMAKE_PROJECT_INCLUDE to use our patched copy (not the nix store original)
    cmakeFlagsArray+=("-DCMAKE_PROJECT_INCLUDE=$PWD/NixpkgsPackages.cmake")
    # Add libcityhash.a to AzCore's link libraries (use real target name AzCore, not alias AZ::AzCore).
    # ''${...} escapes Nix interpolation so CMake variables pass through literally.
    echo 'target_link_libraries(AzCore PRIVATE "''${CMAKE_SOURCE_DIR}/Code/Framework/AzCore/libcityhash.a")' >> Code/Framework/AzCore/CMakeLists.txt
  '';

  buildPhase = ''
    runHook preBuild
    cmake --build . --target Editor -- -j$NIX_BUILD_CORES || \
      cmake --build . -- -j$NIX_BUILD_CORES
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/o3de
    for dir in Code Templates Gems Registry cmake scripts; do
      [ -d "$dir" ] && cp -r "$dir" "$out/share/o3de/$dir"
    done
    cp engine.json version.json "$out/share/o3de/" 2>/dev/null || true

    mkdir -p $out/bin
    cmake --install build --prefix $out 2>/dev/null || true

    mkdir -p $out/include
    cp -r Code/Framework/*/Include/* $out/include/ 2>/dev/null || true

    mkdir -p $out/lib/o3de-python
    ln -sf ${pythonEnv}/bin/python3 $out/lib/o3de-python/python 2>/dev/null || true

    makeWrapper ${pythonEnv}/bin/python3 $out/bin/o3de \
      --prefix PYTHONPATH : "$out/share/o3de/scripts:$out/share/o3de/cmake" \
      --add-flags "-m o3de" \
      --set O3DE_DEV_PATH $out/share/o3de

    for bin in Editor AssetProcessor MaterialCanvas; do
      if [ -f "$out/bin/$bin" ]; then
        makeWrapper "$out/bin/$bin" "$out/bin/o3de-$(echo $bin | tr '[:upper:]' '[:lower:]')" \
          --set O3DE_DEV_PATH $out/share/o3de \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath ([ pkgs.vulkan-loader stdenv.cc.cc.lib ] ++ qtInputs)}
      fi
    done

    find $out/lib -type f -name '*.so' -exec patchelf --set-rpath "$out/lib:${lib.makeLibraryPath ([ pkgs.vulkan-loader stdenv.cc.cc.lib ] ++ qtInputs)}" {} \; 2>/dev/null || true

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "O3DE Editor";
      exec = "o3de-editor %F";
      icon = "o3de";
      desktopName = "O3DE Editor";
      genericName = "Open 3D Engine Editor";
      categories = [ "Development" "IDE" "Graphics" ];
      mimeTypes = [ "application/x-o3de-project" ];
      startupWMClass = "O3DE Editor";
      startupNotify = true;
    })
  ];

  postFixup = ''
    if [ -f $out/share/o3de/Code/Editor/Resources/EditorIcon.png ]; then
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp $out/share/o3de/Code/Editor/Resources/EditorIcon.png $out/share/icons/hicolor/256x256/apps/o3de.png
    fi
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "O3DE (Open 3D Engine) — open-source, cross-platform game engine for real-time 3D development";
    longDescription = ''
      O3DE is an open-source, cross-platform game engine designed for real-time
      3D development.

      Build approach: CDN is dead (403), so a CMake overlay
      (NixpkgsPackages.cmake) pre-defines 3rdParty::* targets from nixpkgs,
      which causes O3DE's package system to skip CDN downloads.  Tier 1/2
      packages (zlib, OpenSSL, libpng, etc.) are aliased directly.
      Python 3.10 (from nixpkgs-stable) is used to match O3DE's pinned
      numpy==1.23.0 compatibility requirements.
    '';
    homepage = "https://o3de.org";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ];
    platforms = lib.platforms.linux;
    mainProgram = "o3de";
  };
})
