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

          # Every continuation prompt must be wrapped. 6 occurrences:
          # the 5 wake sites the patch wraps + the helper's own definition.
          # (The fork's Agent Spaces expansion — commit fd5555e — already fixed
          # the other sites upstream, so the patch now wraps 5, not the 10 of
          # the older 0.17/0.16 fork. The 32bc135 re-vendor changed site forms
          # — team_broadcast's arg rename args2→args, team-shutdown a
          # shutdownText variable, pending-messages client3→client — and the
          # anchors were re-derived in patches/opencode-ensemble.py. See
          # fork.nix comment + patches log.)
          wraps = src.count("__ensembleWakeArgs(")
          assert wraps == 6, f"expected 6 __ensembleWakeArgs( occurrences, found {wraps}"

          # The bare promptAsync({ sites are the fork's OWN call sites (commit
          # fd5555e/32bc135 Agent Spaces expansion), which already thread
          # agent/model into all of them (`getMemberModel(...)` /
          # `...model ? { model } : {}`). That is exactly why the patch only
          # has to wrap the 5 remaining un-modeled sites. 7 bare sites in the
          # current patched bundle (was 8 pre-32bc135: one wake site per
          # pending-messages gained a getMemberModel read); the hash-guard
          # (opencode-ensemble-vendor_test.nix) pins this exact bundle, so any
          # drift shows up there first as a hash mismatch.
          bare = src.count("promptAsync({")
          assert bare == 7, f"expected 7 un-wrapped promptAsync({{ sites (32bc135 fork baseline), found {bare}"

          # The helper resolves a lead/member wake's model. It first reads the
          # stored team.lead_agent/lead_model snapshot; the fd5555e fork adds
          # the lead_agent column via `ALTER TABLE team ADD COLUMN lead_agent
          # TEXT` in its MIGRATIONS list. The stock 0.19.0 dist ships NO writer
          # that ever populates lead_model (team_create still inserts the
          # pre-snapshot 8 columns), so the column stays NULL on every team.
          #
          # That gap used to mean the helper returned opts unchanged, the wake
          # fired a bare promptAsync, and opencode answered the LEAD on its
          # server default — silently undoing the user's model selection the
          # moment a teammate reported in (the "main agent switches back to
          # DeepSeek after a teammate responds" regression). The helper now
          # falls back to reading the lead session's CURRENT model from
          # OpenCode's own DB (readSessionModel) whenever the stored value is
          # NULL. Assert that fallback is wired and the columns are read.
          assert "SELECT lead_agent, lead_model FROM team" in src, "helper must read stored lead_agent/lead_model"
          assert "model = lead.lead_model" in src, "helper must assign stored lead_model"
          assert "readSessionModel(opts.sessionID)" in src, "helper must fall back to readSessionModel for a NULL stored model"
          assert src.count("ALTER TABLE team ADD COLUMN lead_agent TEXT") == 1, "team_create snapshot migration (lead_agent) missing"

          # Bundle must still be valid ESM (mirrors fork.nix's node --check).
          tmp = "/tmp/opencode-ensemble-fork-check.mjs"
          open(tmp, "w").write(src)
          assert os.system(f"${pkgs.nodejs}/bin/node --check {tmp}") == 0, "node --check failed"
          os.unlink(tmp)

          print("ok: 5/5 wake sites wrapped; spawn intact; lead_model NULL-fallback to readSessionModel present; ESM parses")
          PYEOF
        '';
      }
    ];
  };
}
