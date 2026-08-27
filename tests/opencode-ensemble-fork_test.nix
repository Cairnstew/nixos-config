# Regression tests for the vendored opencode-ensemble fork
# (modules/home/opencode/fork.nix + patches/opencode-ensemble.py).
#
# The fork wraps every team-continuation `promptAsync({sessionID, parts})` call
# with __ensembleWakeArgs so a session's agent/model survives wake re-prompts
# (wake-path defect: upstream opencode-ensemble still broken through 0.17.0).
# These tests run against the ACTUAL built bundle (the bytes the flake installs
# to ~/.config/opencode/plugins/opencode-ensemble.js) and assert the patch
# invariants, so an anchor drift or a missed site fails loudly at test time
# too, not only at build time.
{ pkgs, lib, ... }:
let
  fork = import ../modules/home/opencode/fork.nix { inherit pkgs; };
in
{
  suites."opencode-ensemble-fork-tests" = {
    pos = __curPos;
    tests = [
      {
        name = "fork-bundle-wraps-all-wake-sites-and-parses";
        type = "script";
        script = ''
          set -euo pipefail
          bundle=${fork}
          ${pkgs.python3}/bin/python3 - "$bundle" <<'PYEOF'
          import re, sys, os

          path = sys.argv[1]
          src = open(path, encoding="utf-8", errors="replace").read()

          # Every continuation prompt must be wrapped. Exactly 11 occurrences:
          # the 10 wrapped wake sites + the helper's own definition.
          wraps = src.count("__ensembleWakeArgs(")
          assert wraps == 11, f"expected 11 __ensembleWakeArgs( occurrences, found {wraps}"

          # The only bare promptAsync({ must be the spawn site (which already
          # carries agent/model by construction).
          bare = src.count("promptAsync({")
          assert bare == 1, f"expected exactly 1 un-wrapped promptAsync({{ (spawn), found {bare}"

          # Migration 9 (team.lead_model) must be present.
          assert src.count("ADD COLUMN lead_model") == 1, "lead_model migration missing"

          # team_create snapshot must be present.
          assert "snapshot the lead" in src, "team_create snapshot missing"

          # Bundle must still be valid ESM (mirrors fork.nix's node --check).
          tmp = "/tmp/opencode-ensemble-fork-check.mjs"
          open(tmp, "w").write(src)
          assert os.system(f"${pkgs.nodejs}/bin/node --check {tmp}") == 0, "node --check failed"
          os.unlink(tmp)

          print("ok: 11/11 wake sites wrapped; spawn intact; migration 9 present; ESM parses")
          PYEOF
        '';
      }
    ];
  };
}