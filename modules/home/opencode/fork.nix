# Vendored fork of @hueyexe/opencode-ensemble 0.16.1 — wake-path fix.
#
# Upstream publishes a single-file dist (dist/index.js, node-core imports only)
# that this repo installs as a LOCAL plugin (via cfg.pluginFiles →
# ~/.config/opencode/plugins/opencode-ensemble.js) INSTEAD of the npm spec
# (modules/nixos/homeManager/config.nix `plugins`), because upstream has NOT
# fixed the wake-path defect through 0.17.0 (verified 2026-08-26) and a local
# plugin is the only place a build-time patch can be applied durably.
#
# The defect: every team continuation (wake-lead, member delivery, broadcast,
# shutdown nudge, watchdog/stall/peer nudges, pending-message wakes) re-prompts
# a session with promptAsync({ sessionID, parts }) and NO agent/model, so the
# session silently falls back to the global default after the first turn.
#
# The patch (patches/opencode-ensemble.py):
#   * Migration 9 — team.lead_model TEXT (plugin's own user_version machinery)
#   * team_create — snapshots the lead's resolved model into
#     team.lead_agent/lead_model (message-table read, one-off)
#   * wraps all TEN wake promptAsync sites with __ensembleWakeArgs(db, opts),
#     re-attaching the target session's agent/model (lead: team columns with
#     message-table fallback; members: team_member columns)
#
# The patch script is fail-loud (patch-jar.nix convention): if any anchor in
# the pinned dist is missing, the Nix build fails instead of shipping a
# silently-wrong patch. See FORK.md for the fork policy + rollback.
{ pkgs
,
}:
let
  upstream = pkgs.fetchurl {
    url = "https://registry.npmjs.org/@hueyexe/opencode-ensemble/-/opencode-ensemble-0.16.1.tgz";
    # published 2026-08-15; dist is the ONLY runtime artifact (src not shipped in npm files)
    sha256 = "2f3268a2d87ed1918b0fc6d20a2bc4386dd0b796ebf63d00442cbb5119a94a98";
  };

  patchScript = ./patches/opencode-ensemble.py;
in
pkgs.runCommand "opencode-ensemble-0.16.1-fork"
{
  nativeBuildInputs = [
    pkgs.gnutar
    pkgs.python3
    pkgs.nodejs
  ];
} ''
  set -euo pipefail
  tar xzf '${upstream}'
  python3 '${patchScript}' package/dist/index.js patched.js
  # The bundle is ESM (import.meta.url). node --check needs the .mjs suffix to
  # parse it as a module, otherwise CommonJS mode trips on `import`.
  cp patched.js patched.mjs
  '${pkgs.nodejs}/bin/node' --check patched.mjs
  cp patched.js "$out"
''
