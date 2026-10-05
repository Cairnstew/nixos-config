# Vendored fork of @hueyexe/opencode-ensemble from GitHub repository.
#
# Source: https://github.com/Cairnstew/opencode-ensemble (commit 32bc135)
# This is a fork of the original @hueyexe/opencode-ensemble that includes
# the Agent Spaces feature, the wake-path fix, the Agent Spaces expansion
# (richer metadata, clone-on-demand, deterministic handoff protocol), and
# lead-session model inheritance (spawn-side resolved model, added 32bc135).
#
# The GitHub repository contains only source files (src/), not pre-built dist.
# Since the Nix sandbox doesn't have network access to install dependencies,
# we vendor the pre-built dist/index.js from the local build and apply the
# patch to it.
#
# The patch (patches/opencode-ensemble.py):
#   * wraps FIVE remaining wake promptAsync sites that lack model handling
#     with __ensembleWakeArgs(db, opts)
#   * __ensembleWakeArgs reads the recipient's stored model (team.lead_model
#     for the lead, team_member.model for a teammate) and, when the stored
#     lead model is NULL, falls back to reading the lead session's CURRENT
#     model from OpenCode's own SQLite DB (readSessionModel).
#
# The fallback is load-bearing, not defensive. The stock 0.19.0 dist ships no
# writer for team.lead_model — team_create still inserts the pre-snapshot 8
# columns — so the column is NULL on every team. Without the fallback the
# helper returned opts unchanged, the wake fired a bare promptAsync, and
# opencode answered the lead on its SERVER DEFAULT, silently undoing the
# user's model selection the moment a teammate reported in.
#
# The patch script is fail-loud (patch-jar.nix convention): if any anchor in
# the pinned dist is missing, the Nix build fails instead of shipping a
# silently-wrong patch. See FORK.md for the fork policy + rollback.
{ pkgs
,
}:
let
  # Pre-built dist/index.js from the local build of Cairnstew/opencode-ensemble
  # (commit 32bc135 — Agent Spaces expansion + lead-session model inheritance;
  #  re-vendored via tools/revendor-opencode-ensemble.sh, anchors re-derived)
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
