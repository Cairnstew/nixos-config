# =============================================================================
# packages/opencode/default.nix — opencode prebuilt binary (x86_64-linux)
# =============================================================================
# Purpose: Pin opencode to a version whose web UI actually works.
#
# The flake's nixpkgs input (2026-06-10) ships opencode 1.16.2, whose web
# frontend crashes on load with `Settings context must be used within a context
# provider` (upstream anomalyco/opencode#30478), breaking every browser
# interaction including permission prompts. Verified fixed in 1.18.13.
#
# Rather than bump the whole nixpkgs input (a ~2-month package-set jump) just
# to pick this up, fetch the official release binary here. Matches the repo's
# prebuilt-binary pattern (see packages/endcord).
#
# Platforms: x86_64-linux (official release artifact is linux-x64 only).
# =============================================================================

{ lib, stdenv, fetchurl, autoPatchelfHook, makeBinaryWrapper }:

stdenv.mkDerivation (finalAttrs: {
  pname = "opencode";
  version = "1.18.13";

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${finalAttrs.version}/opencode-linux-x64.tar.gz";
    hash = "sha256-jVALIP7S0m5TfiIYlbGldUdlcbTwCJuyn7E+64656Tc=";
  };

  nativeBuildInputs = [ autoPatchelfHook makeBinaryWrapper ];

  dontConfigure = true;
  dontBuild = true;
  # The release tarball is a bare `opencode` file (no wrapping directory), which
  # trips the default unpackPhase ("produced no directories"). Extract manually.
  dontUnpack = true;
  # Bun-compiled single-file executables corrupt when `strip` rewrites ELF
  # sections (the store build reported a wrong `--version` and lost the `web`
  # command). Keep the binary byte-identical apart from the interpreter/rpath.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    tar -xOzf "$src" opencode > $out/bin/opencode
    chmod +x $out/bin/opencode
    # Mirror the nixpkgs wrapper: libstdc++ for the native file-watcher binding,
    # and block self-update so upgrades go through Nix.
    wrapProgram $out/bin/opencode \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ stdenv.cc.cc.lib ]} \
      --set OPENCODE_DISABLE_AUTOUPDATE true
    runHook postInstall
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencode";
    maintainers = [ ];
  };
})
