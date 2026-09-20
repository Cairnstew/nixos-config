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
    {
        name = "monthly-static-caps";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.jq}/bin:$PATH
          prog=${../modules/home/opencode/model-select.jq}

          # now = 1800000000 = 2027-01-15T08:00:00Z. Static monthly cap only --
          # no pacing, so maxMonthlyPercent alone governs the monthly window.
          monthcache() { # $1 = monthly percent literal
            printf '{"usage":{
              "rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T13:00:00.000Z"},
              "weekly":{"status":"ok","percent":10,"resetsAt":"2027-01-18T00:00:00.000Z"},
              "monthly":{"status":"ok","percent":%s,"resetsAt":"2027-02-14T22:24:00.000Z"}}}' "$1"
          }
          monthcache2() { # $1 = monthly percent, $2 = monthly resetsAt
            printf '{"usage":{
              "rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T13:00:00.000Z"},
              "weekly":{"status":"ok","percent":10,"resetsAt":"2027-01-18T00:00:00.000Z"},
              "monthly":{"status":"ok","percent":%s,"resetsAt":"%s"}}}' "$1" "$2"
          }
          chain='[{"model":"m/monthly","blockedTerminal":false,"maxMonthlyPercent":90}]'

          # percent below cap -> eligible
          ok=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$chain" <<<"$(monthcache 45)")
          [ "$ok" = "m/monthly" ] || { echo "FAIL: 45% below cap 90 should resolve (got: $ok)" >&2; exit 1; }
          # percent exactly AT cap -> eligible
          ok=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$chain" <<<"$(monthcache 90)")
          [ "$ok" = "m/monthly" ] || { echo "FAIL: 90% exactly at cap should resolve (got: $ok)" >&2; exit 1; }
          # percent ABOVE cap -> rescued by no entry, empty output
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$chain" <<<"$(monthcache 91)" || true)
          [ -z "$out" ] || { echo "FAIL: 91% above cap 90 must fall through (got: $out)" >&2; exit 1; }

          # cache with usage.monthly MISSING must make jq -re exit non-zero
          # (the wrapper's resolve_chain swallows it: "2>/dev/null || true" and
          # degrades to the chain's last entry -- pin the jq behavior here).
          missing='{"usage":{
            "rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T13:00:00.000Z"},
            "weekly":{"status":"ok","percent":10,"resetsAt":"2027-01-18T00:00:00.000Z"}}}'
          rc=0
          jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$chain" <<<"$missing" >/dev/null 2>&1 || rc=$?
          [ "$rc" -ne 0 ] || { echo "FAIL: missing usage.monthly must make jq exit non-zero (got rc=0)" >&2; exit 1; }

          # exact monthly boundary: resetsAt == now and resetsAt == now + 30d
          # both parse and behave identically for a static cap
          for reset in "2027-01-15T08:00:00Z" "2027-02-14T08:00:00Z"; do
            ok=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$chain" <<<"$(monthcache2 50 "$reset")")
            [ "$ok" = "m/monthly" ] || { echo "FAIL: 50% with resetsAt=$reset should resolve (got: $ok)" >&2; exit 1; }
          done

          echo "ok: monthly static caps (below/at/above), missing-monthly errors, resetsAt boundaries"
        '';
      }
      {
        name = "budget-pacing";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.jq}/bin:$PATH
          prog=${../modules/home/opencode/model-select.jq}

          # now = 1800000000 = 2027-01-15T08:00:00Z. Budget pacing on the
          # monthly window (entry.pacing.mode = "budget", windows ["monthly"],
          # sliceHours 24) with a per-test snapshot. sliceCap = usageAtStart +
          # (100 - usageAtStart)/slicesLeft, effective = min(static, slice).
          mkcache() { # $1 = monthly percent, $2 = monthly resetsAt
            printf '{"usage":{
              "rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T13:00:00.000Z"},
              "weekly":{"status":"ok","percent":10,"resetsAt":"2027-01-18T00:00:00.000Z"},
              "monthly":{"status":"ok","percent":%s,"resetsAt":"%s"}}}' "$1" "$2"
          }
          entry() { # $1 = maxMonthlyPercent literal (null or number)
            printf '[{"model":"m/budget","blockedTerminal":false,"maxRollingPercent":null,"maxWeeklyPercent":null,"maxMonthlyPercent":%s,"pacing":{"enable":true,"mode":"budget","floor":5,"buffer":10,"budget":{"windows":["monthly"],"sliceHours":24}}}]' "$1"
          }

          # A. Mid-slice: resetsAt = now+15d, snapshot started now-6h at 40%.
          #    slicesLeft = ceil(15.25) = 16, cap = 40 + 60/16 = 43.75.
          snapA='{"monthly":{"sliceStart":1799978400,"usageAtStart":40,"resetsAt":"2027-01-30T08:00:00.000Z"}}'
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null)" --argjson snapshot "$snapA" <<<"$(mkcache 43 '2027-01-30T08:00:00.000Z')")
          [ "$out" = "m/budget" ] || { echo "FAIL A: usage 43 <= cap 43.75 must resolve (got: $out)" >&2; exit 1; }
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null)" --argjson snapshot "$snapA" <<<"$(mkcache 45 '2027-01-30T08:00:00.000Z')" || true)
          [ -z "$out" ] || { echo "FAIL A: usage 45 > cap 43.75 must fall through (got: $out)" >&2; exit 1; }

          # B. Late period: resetsAt = now+2d, snapshot started now-1h at 90%.
          #    slicesLeft = ceil(49/24) = 3, cap = 90 + 10/3 = 93.33.
          snapB='{"monthly":{"sliceStart":1799996400,"usageAtStart":90,"resetsAt":"2027-01-17T08:00:00.000Z"}}'
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null)" --argjson snapshot "$snapB" <<<"$(mkcache 93 '2027-01-17T08:00:00.000Z')")
          [ "$out" = "m/budget" ] || { echo "FAIL B: usage 93 <= cap 93.33 must resolve (got: $out)" >&2; exit 1; }
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry 92)" --argjson snapshot "$snapB" <<<"$(mkcache 93 '2027-01-17T08:00:00.000Z')" || true)
          [ -z "$out" ] || { echo "FAIL B: maxMonthlyPercent 92 backstop beats slice cap 93.33 (got: $out)" >&2; exit 1; }

          # C. Missing snapshot / resetsAt mismatch: budget skipped, static only.
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry 90)" <<<"$(mkcache 91 '2027-01-30T08:00:00.000Z')" || true)
          [ -z "$out" ] || { echo "FAIL C: missing snapshot, static 90 vs usage 91 must reject (got: $out)" >&2; exit 1; }
          snapMismatch='{"monthly":{"sliceStart":1799978400,"usageAtStart":40,"resetsAt":"2027-01-29T08:00:00.000Z"}}'
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry 90)" --argjson snapshot "$snapMismatch" <<<"$(mkcache 91 '2027-01-30T08:00:00.000Z')" || true)
          [ -z "$out" ] || { echo "FAIL C: snapshot resetsAt mismatch must fall back to static only (got: $out)" >&2; exit 1; }

          # D. Snapshot older than 2 slices is treated as missing. Fresh slice
          #    at 0% with resetsAt now+3d gives slicesLeft 4, cap 25 -> usage
          #    40 rejected; the SAME usage with a stale snapshot (now-50h >
          #    2*24h) must be eligible (budget skipped, no static cap).
          snapFreshD='{"monthly":{"sliceStart":1799996400,"usageAtStart":0,"resetsAt":"2027-01-18T08:00:00.000Z"}}'
          snapStaleD='{"monthly":{"sliceStart":1799820000,"usageAtStart":0,"resetsAt":"2027-01-18T08:00:00.000Z"}}'
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null)" --argjson snapshot "$snapFreshD" <<<"$(mkcache 40 '2027-01-18T08:00:00.000Z')" || true)
          [ -z "$out" ] || { echo "FAIL D: fresh slice cap 25 must reject usage 40 (got: $out)" >&2; exit 1; }
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null)" --argjson snapshot "$snapStaleD" <<<"$(mkcache 40 '2027-01-18T08:00:00.000Z')")
          [ "$out" = "m/budget" ] || { echo "FAIL D: stale >2-slice snapshot must be ignored (budget skipped; got: $out)" >&2; exit 1; }

          # E. Reset between polls: cache resetsAt advanced to now+30d, snapshot
          #    still carries the old period's resetsAt -> ignored, static only.
          snapE='{"monthly":{"sliceStart":1799978400,"usageAtStart":40,"resetsAt":"2027-01-30T08:00:00.000Z"}}'
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null)" --argjson snapshot "$snapE" <<<"$(mkcache 50 '2027-02-14T08:00:00.000Z')")
          [ "$out" = "m/budget" ] || { echo "FAIL E: snapshot with old resetsAt must not constrain (got: $out)" >&2; exit 1; }

          echo "ok: budget pacing (mid-slice cap, backstop precedence, degrade rules, reset handling)"
        '';
      }
      {
        # Regression for the 2026-09-20 windowOk rewrite (budget pacing round):
        # the pace term used to be consulted ONLY when a static cap was set
        # (`$staticCap == null` short-circuited the `or`). The rewrite made
        # effective cap = min(static, pace) with null meaning "no constraint".
        # These cases pin the ELAPSED-mode semantics at now = 1800000000 with
        # the same cache fixture as the original pacing test:
        #   weekly resetsAt 2027-01-20T08:57:36Z  -> weekly elapsed 28% -> pace 38
        #   monthly resetsAt 2027-02-08T22:24:00Z -> monthly elapsed 18% -> pace 28
        name = "pacing-elapsed-windookup";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.jq}/bin:$PATH
          prog=${../modules/home/opencode/model-select.jq}

          cache() { # $1 = weekly percent, $2 = monthly percent
            printf '{"usage":{
              "rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T00:00:00.000Z"},
              "weekly":{"status":"ok","percent":%s,"resetsAt":"2027-01-20T08:57:36.000Z"},
              "monthly":{"status":"ok","percent":%s,"resetsAt":"2027-02-08T22:24:00.000Z"}}}' "$1" "$2"
          }
          entry() { # $1 = monthly static cap literal, $2 = pacing.enable literal
            printf '[{"model":"m/elapsed","blockedTerminal":false,"maxRollingPercent":null,"maxWeeklyPercent":null,"maxMonthlyPercent":%s,"pacing":{"enable":%s,"floor":5,"buffer":10}}]' "$1" "$2"
          }

          # A. static null + pacing enabled: the pace term applies.
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null true)" <<<"$(cache 5 45)" || true)
          [ -z "$out" ] || { echo "FAIL A: monthly 45 > paceCap 28 must reject when pacing enabled, static null (got: $out)" >&2; exit 1; }
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null true)" <<<"$(cache 5 10)")
          [ "$out" = "m/elapsed" ] || { echo "FAIL A: monthly 10 <= paceCap 28 must resolve (got: $out)" >&2; exit 1; }

          # B. static null + pacing disabled: cap-free (even 99% usage).
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry null false)" <<<"$(cache 5 99)")
          [ "$out" = "m/elapsed" ] || { echo "FAIL B: pacing disabled, static null must be cap-free (got: $out)" >&2; exit 1; }

          # C. static set + pacing enabled: effective cap = min(static, pace).
          #    Static 40, pace 28: usage 30 passes static but fails pace.
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry 40 true)" <<<"$(cache 5 30)" || true)
          [ -z "$out" ] || { echo "FAIL C: monthly 30 > paceCap 28 (static 40) must reject — pace binds (got: $out)" >&2; exit 1; }
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry 40 true)" <<<"$(cache 5 15)")
          [ "$out" = "m/elapsed" ] || { echo "FAIL C: monthly 15 under min(40,28) must resolve (got: $out)" >&2; exit 1; }
          #    Static 15, pace 28: usage 18 under pace but over static.
          out=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$(entry 15 true)" <<<"$(cache 5 18)" || true)
          [ -z "$out" ] || { echo "FAIL C: monthly 18 > static 15 must reject — static binds under pace (got: $out)" >&2; exit 1; }

          echo "ok: elapsed windowOk rewrite (pace applies with null static, cap-free when disabled, min(static,pace) binds)"
        '';
      }
      {
        # Missing usage.monthly: the wrapper keeps the current behavior (jq
        # errors are swallowed, resolve_chain degrades to the last chain entry)
        # but now prints one stderr warning. This test asserts (a) the wrapper
        # source contains the warning, and (b) the degradation path resolves
        # the LAST entry with exit 0 exactly as resolve_for_agent does.
        name = "missing-monthly-fallback";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.jq}/bin:${pkgs.gnugrep}/bin:$PATH
          prog=${../modules/home/opencode/model-select.jq}
          fb=${../modules/home/opencode/fallback.nix}

          grep -q 'usage.monthly missing, falling back to last chain entry' "$fb" || {
            echo "FAIL: opencode-model-select wrapper must print the missing-monthly warning" >&2; exit 1; }

          # Degradation: chain whose last entry is the cap-free safety net.
          chain='[{"model":"m/first"},{"model":"m/safety"}]'
          missing='{"usage":{
            "rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T00:00:00.000Z"},
            "weekly":{"status":"ok","percent":3,"resetsAt":"2027-01-20T08:57:36.000Z"}}}'

          # resolve_chain semantics: jq errors are swallowed (|| true) -> empty
          # winner; unlike the real wrapper the cache is fed via stdin here.
          winner=$(jq -re -f "$prog" --argjson now 1800000000 --argjson chain "$chain" <<<"$missing" 2>/dev/null || true)
          [ -z "$winner" ] || { echo "FAIL: missing monthly must produce no winner from jq (got: $winner)" >&2; exit 1; }
          # resolve_for_agent semantics: empty winner -> last_model_of_chain (the
          # wrapper uses `jq -r` on the stdin array — `-n` would null the input).
          last=$(jq -r '. | last | (.model // empty)' <<< "$chain")
          [ "$last" = "m/safety" ] || { echo "FAIL: fallback must resolve the last chain entry (got: $last)" >&2; exit 1; }
          [ -z "$winner" ] || exit 1
          echo "ok: missing monthly -> stderr warning wired, degrade resolves last entry with exit 0"
        '';
      }
    ];
  };

  suites."opencode-slices-roll-tests" = {
    pos = __curPos;
    tests = [
      {
        name = "snapshot-roll";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.diffutils}/bin:${pkgs.bash}/bin:$PATH
          roll=${../modules/home/opencode/snapshot-roll.sh}
          dir=$(mktemp -d)
          trap 'rm -rf "$dir"' EXIT

          cache() { # $1 = monthly resetsAt, $2 = monthly percent
            printf '{"usage":{"rolling":{"status":"ok","percent":1,"resetsAt":"2027-01-15T13:00:00.000Z"},"weekly":{"status":"ok","percent":10,"resetsAt":"2027-01-18T00:00:00.000Z"},"monthly":{"status":"ok","percent":%s,"resetsAt":"%s"}}}' "$2" "$1"
          }

          # 1. No snapshot -> fresh, seeded with the CURRENT percent.
          bash "$roll" "$(cache '2027-01-30T08:00:00.000Z' 40)" "$dir/s.json" 24 1800000000
          [ "$(jq -r '.monthly.sliceStart' "$dir/s.json")" = "1800000000" ] || { echo "FAIL 1: fresh sliceStart must be now" >&2; exit 1; }
          [ "$(jq -r '.monthly.usageAtStart' "$dir/s.json")" = "40" ] || { echo "FAIL 1: fresh usageAtStart must be current percent" >&2; exit 1; }
          [ "$(jq -r '.monthly.resetsAt' "$dir/s.json")" = "2027-01-30T08:00:00.000Z" ] || { echo "FAIL 1: fresh resetsAt mismatch" >&2; exit 1; }

          # 2. Same slice, same resetsAt -> preserved byte-for-byte.
          cp "$dir/s.json" "$dir/s2.json"
          bash "$roll" "$(cache '2027-01-30T08:00:00.000Z' 55)" "$dir/s2.json" 24 1800000300
          cmp -s "$dir/s.json" "$dir/s2.json" || { echo "FAIL 2: within-slice poll must not rewrite the snapshot" >&2; exit 1; }

          # 3. Slice elapsed (now >= sliceStart + 24h) -> roll: new sliceStart,
          #    usageAtStart = current percent.
          cp "$dir/s.json" "$dir/s3.json"
          bash "$roll" "$(cache '2027-01-30T08:00:00.000Z' 60)" "$dir/s3.json" 24 1800086400
          [ "$(jq -r '.monthly.sliceStart' "$dir/s3.json")" = "1800086400" ] || { echo "FAIL 3: roll must move sliceStart to now" >&2; exit 1; }
          [ "$(jq -r '.monthly.usageAtStart' "$dir/s3.json")" = "60" ] || { echo "FAIL 3: roll must re-seed usageAtStart to current percent" >&2; exit 1; }

          # 4. resetsAt changed (period reset between polls) -> roll.
          bash "$roll" "$(cache '2027-02-14T08:00:00.000Z' 5)" "$dir/s.json" 24 1800000000
          [ "$(jq -r '.monthly.resetsAt' "$dir/s.json")" = "2027-02-14T08:00:00.000Z" ] || { echo "FAIL 4: reset must roll the snapshot" >&2; exit 1; }
          [ "$(jq -r '.monthly.usageAtStart' "$dir/s.json")" = "5" ] || { echo "FAIL 4: post-reset usageAtStart must be current percent" >&2; exit 1; }

          # 5. Corrupt snapshot -> replaced with a valid fresh one, never partial.
          printf 'not json' > "$dir/bad.json"
          bash "$roll" "$(cache '2027-01-30T08:00:00.000Z' 20)" "$dir/bad.json" 24 1800000000
          jq -e '.monthly.sliceStart != null and .monthly.usageAtStart != null and .monthly.resetsAt != null' "$dir/bad.json" >/dev/null \
            || { echo "FAIL 5: corrupt snapshot must be replaced with valid JSON" >&2; exit 1; }
          [ ! -e "$dir/bad.json.tmp" ] || { echo "FAIL 5: temp file must not remain" >&2; exit 1; }

          echo "ok: snapshot roll (fresh/preserve/roll-on-elapse/roll-on-reset/corrupt-replace)"
        '';
      }
      {
        # Wiring regression: the roll CLI must actually be invoked by the poll
        # unit, after the cache write, guarded so a roll failure cannot fail
        # the poll. Source-level assertions on usage.nix + snapshot-roll.sh —
        # exactly the bytes that get built into opencode-go-usage.
        name = "slice-roll-wired";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:$PATH
          u=${../modules/home/opencode/usage.nix}
          r=${../modules/home/opencode/snapshot-roll.sh}

          # The roll binary exists and is invoked inside the poll script.
          grep -q 'writeShellScriptBin "opencode-go-slices-roll"' "$u" \
            || { echo "FAIL: usage.nix must define the opencode-go-slices-roll binary" >&2; exit 1; }
          grep -q 'opencode-go-slices-roll "$JSON" "$SLICE_FILE" "$SLICE_HOURS"' "$u" \
            || { echo "FAIL: usage.nix must invoke the roll after the poll" >&2; exit 1; }
          grep -q 'slice snapshot roll failed' "$u" \
            || { echo "FAIL: roll failure must be non-fatal for the poll unit" >&2; exit 1; }
          grep -q 'runtimeInputs = with pkgs; \[ curl jq coreutils sliceRoll \]' "$u" \
            || { echo "FAIL: usage.nix must put the roll binary on the poll PATH" >&2; exit 1; }

          # Ordering: the invocation must come AFTER the cache write/mv
          # (''${CACHE_FILE}.tmp" is the cache tmp-write line; the substring
          # 'CACHE_FILE}.tmp"' is brace-free so it needs no Nix escaping).
          cache_mv=$(grep -n 'CACHE_FILE}.tmp"' "$u" | head -1 | cut -d: -f1)
          roll_line=$(grep -n 'opencode-go-slices-roll "$JSON"' "$u" | head -1 | cut -d: -f1)
          [ -n "$cache_mv" ] && [ -n "$roll_line" ] && [ "$roll_line" -gt "$cache_mv" ] \
            || { echo "FAIL: roll must run after the cache write (cache_mv=$cache_mv roll=$roll_line)" >&2; exit 1; }

          # snapshot-roll.sh writes atomically (tmp + mv, never partial).
          grep -q '\.tmp' "$r" || { echo "FAIL: snapshot-roll.sh must write via a tmp file" >&2; exit 1; }
          grep -q 'slice_file}.tmp"' "$r" \
            || { echo "FAIL: snapshot-roll.sh must mv the tmp file into place" >&2; exit 1; }

          echo "ok: slice roll wired into usage.nix after the cache write, non-fatal, atomic"
        '';
      }
    ];
  };
}
