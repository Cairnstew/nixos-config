# Vendored fork of @hueyexe/opencode-ensemble from GitHub repository.
#
# Source: https://github.com/Cairnstew/opencode-ensemble (commit fd5555e)
# This is a fork of the original @hueyexe/opencode-ensemble that includes
# the Agent Spaces feature, the wake-path fix, and the Agent Spaces expansion
# (richer metadata, clone-on-demand, deterministic handoff protocol).
#
# The GitHub repository contains only source files (src/), not pre-built dist.
# Since the Nix sandbox doesn't have network access to install dependencies,
# we vendor the pre-built dist/index.js from the local build and apply the
# patch to it.
#
# The patch (patches/opencode-ensemble.py):
#   * Migration 12 — team.lead_model TEXT (plugin's own user_version machinery)
#   * team_create — snapshots the lead's resolved model into
#     team.lead_agent/lead_model (message-table read, one-off)
#   * wraps FIVE remaining wake promptAsync sites that lack model handling
#     with __ensembleWakeArgs(db, opts)
#
# The patch script is fail-loud (patch-jar.nix convention): if any anchor in
# the pinned dist is missing, the Nix build fails instead of shipping a
# silently-wrong patch. See FORK.md for the fork policy + rollback.
{ pkgs
,
}:
let
  # Pre-built dist/index.js from the local build of Cairnstew/opencode-ensemble
  # (commit fd5555e — Agent Spaces expansion: richer metadata, clone-on-demand,
  #  deterministic handoff protocol)
  upstream = ./vendor/opencode-ensemble-0.19.0-dist.js;

  patchScript = ./patches/opencode-ensemble.py;
in
pkgs.runCommand "opencode-ensemble-fork"
{
  nativeBuildInputs = [
    pkgs.python3
    pkgs.nodejs
  ];
} ''
  set -euo pipefail
  cp '${upstream}' dist.js
  python3 '${patchScript}' dist.js patched.js
  # The bundle is ESM (import.meta.url). node --check needs the .mjs suffix to
  # parse it as a module, otherwise CommonJS mode trips on `import`.
  cp patched.js patched.mjs
  '${pkgs.nodejs}/bin/node' --check patched.mjs
  cp patched.js "$out"
''
