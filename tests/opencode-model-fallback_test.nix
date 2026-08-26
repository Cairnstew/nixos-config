# Behavioral regression tests for the opencode-model-select resolution
# program (modules/home/opencode/model-select.jq — imported by fallback.nix,
# so these tests run the exact bytes the deployed selector runs).
#
# Regression (2026-08-26, self-improve-usage Tier 1 Task 2 / Tier 0 §2c):
# pacing was applied even when pacing.enable was false — paceCap consulted
# entry.pacing.floor/buffer but never the enable flag — leaving whole chains
# BLOCKED at moderate usage. Diagnostic signature of that bug class: a chain
# resolves BLOCKED while ROLLING sits near 0% and every static cap passes.
#
# The snapshot below is chosen so pacing-on and pacing-off produce DIFFERENT
# eligibility for the same entry:
#   rolling 1%, weekly 55%, monthly 45%
#   weekly elapsed 28% → paceCap = min(100, 28+10) = 38   (< 55 → paced out)
#   monthly elapsed 18% → paceCap = min(100, 18+10) = 28  (< 45 → paced out)
#   entry caps: maxRollingPercent 40, maxWeeklyPercent 60 (static-passing)
# enable=false must match static-only evaluation → eligible.
# enable=true  must be paced out on both windows → no survivor.
{ pkgs, lib, ... }: {
  suites."opencode-model-fallback-tests" = {
    pos = __curPos;
    tests = [
      {
        name = "pacing-enable-false-matches-static-only";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.jq}/bin:$PATH
          prog=${../modules/home/opencode/model-select.jq}

          cache='{"usage":{
            "rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T00:00:00.000Z"},
            "weekly":{"status":"ok","percent":55,"resetsAt":"2027-01-20T08:57:36.000Z"},
            "monthly":{"status":"ok","percent":45,"resetsAt":"2027-02-08T22:24:00.000Z"}}}'

          mkentry() {  # $1 = pacing.enable JSON literal
            printf '[{"model":"m/test","blockedTerminal":false,"maxRollingPercent":40,"maxWeeklyPercent":60,"maxMonthlyPercent":null,"pacing":{"enable":%s,"floor":5,"buffer":10}}]' "$1"
          }

          off=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(mkentry false)" <<<"$cache")
          [ "$off" = "m/test" ] || {
            echo "FAIL: enable=false should match static-only evaluation (expected m/test), got: $off" >&2
            exit 1
          }

          on=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(mkentry true)" <<<"$cache" || true)
          [ -z "$on" ] || {
            echo "FAIL: enable=true should be paced out (empty), got: $on" >&2
            exit 1
          }

          echo "ok: enable=false resolved statically (m/test); enable=true paced out"
        '';
      }
    ];
  };
}
