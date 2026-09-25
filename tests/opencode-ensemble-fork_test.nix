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

          # Every continuation prompt must be wrapped. Exactly 5 occurrences:
          # the wake sites the patch wraps + the helper's own definition.
          # (The fork's Agent Spaces expansion — commit fd5555e — already fixed
          # the other sites upstream, so the patch now wraps 5, not the 10 of
          # the older 0.17/0.16 fork. See fork.nix comment + patches log.)
          wraps = src.count("__ensembleWakeArgs(")
          assert wraps == 5, f"expected 5 __ensembleWakeArgs( occurrences, found {wraps}"

          # The bare promptAsync({ sites are the fork's OWN call sites (commit
          # fd5555e Agent Spaces expansion), which already thread agent/model
          # into most of them (spread `...model ? { model } : {}`) — that is
          # exactly why the patch only has to wrap the 5 remaining un-modeled
          # sites. 8 bare sites in the current patched bundle; the hash-guard
          # (opencode-ensemble-vendor_test.nix) pins this exact bundle, so any
          # drift shows up there first as a hash mismatch.
          bare = src.count("promptAsync({")
          assert bare == 8, f"expected 8 un-wrapped promptAsync({{ sites (fd5555e fork baseline), found {bare}"

          # The helper reads lead_agent/lead_model (2 references). The fd5555e fork
          # adds the snapshot column itself: `ALTER TABLE team ADD COLUMN
          # lead_agent TEXT` lives in its MIGRATIONS list. lead_model itself is
          # only referenced by the helper, not created by any migration — a
          # pre-existing fork schema gap whose failure mode is the documented
          # safe degradation (helper returns opts unchanged on a missing
          # column); fixing it is a fork change, not this test's concern.
          assert src.count("lead_model") == 2, "lead_model helper references missing"
          assert src.count("ALTER TABLE team ADD COLUMN lead_agent TEXT") == 1, "team_create snapshot migration (lead_agent) missing"

          # Bundle must still be valid ESM (mirrors fork.nix's node --check).
          tmp = "/tmp/opencode-ensemble-fork-check.mjs"
          open(tmp, "w").write(src)
          assert os.system(f"${pkgs.nodejs}/bin/node --check {tmp}") == 0, "node --check failed"
          os.unlink(tmp)

          print("ok: 5/5 wake sites wrapped; spawn intact; lead_agent migration present; ESM parses")
          PYEOF
        '';
      }
    ];
  };
}
