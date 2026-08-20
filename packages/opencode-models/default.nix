# =============================================================================
# packages/opencode-models/default.nix — model pricing/capabilities lookup
# =============================================================================
# Purpose: A zero-dependency CLI that queries models.dev (the catalog powering
# OpenCode's `/models` browser and https://opencode.ai/go) and prints a
# cost-ranked table of LLM models — pricing per 1M tokens, context/output
# limits, and capability flags — so you can pick the most cost-effective model.
#
# Defaults to the `opencode-go` provider (OpenCode Go subscription), but
# `--provider all` covers the whole catalog. The engine is
# packages/opencode-models/opencode_models.py (stdlib only); this derivation
# just installs it and rewrites its `#!/usr/bin/env python3` shebang to the
# Nix python3 via patchShebangs.
#
# Output: packages.${system}.opencode-models (auto-wired by nixos-unified).
# Run: `nix run .#opencode-models [args]` — see --help.
# =============================================================================

{ lib, python3, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "opencode-models";
  version = "1.0.0";

  src = ./.;

  # Put python3 in nativeBuildInputs so patchShebangs rewrites the script's
  # shebang to this exact python3 (and Nix records it as a runtime dep).
  nativeBuildInputs = [ python3 ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin"
    install -m755 opencode_models.py "$out/bin/opencode-models"
    patchShebangs "$out/bin/opencode-models"
    runHook postInstall
  '';

  meta = {
    description = "Query LLM model pricing, limits, and capabilities from models.dev (OpenCode Go & the whole catalog)";
    mainProgram = "opencode-models";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
