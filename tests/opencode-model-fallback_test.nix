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
{ pkgs, lib, realChains ? null, ... }:
let
  # The LIVE chains from modules/nixos/homeManager/config.nix, evaluated by
  # the nixtest harness (modules/flake-parts/nixtest.nix) and serialized as
  # the exact ~/.config/opencode/model-fallback.json payload the deployed
  # selector consumes. Replaces the hand-copied fixtures (which drifted from
  # the config's option-default expansion — blockedTerminal/model:null/pacing
  # defaults appear in the evaluated value but not in the hand copy). Written
  # to a store path so the scripts reference it without heredoc/quoting
  # pitfalls inside Nix '' strings.
  chainsConfig = pkgs.writeText "model-fallback-test.json" (builtins.toJSON { chains = realChains; });
  chainsFile = "${chainsConfig}";
in
{
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
        name = "pacing-elapsed-windowok";
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
    ];
  };

  # BEHAVIOURAL tests of the real selector wrapper (modules/home/opencode/
  # model-select.sh — the exact bytes run by fallback.nix's opencode-model-select,
  # env-parameterized via OPENCODE_SELECT_*). Source-level greps cannot catch
  # shell logic bugs (the jq -rn safety-net bug slipped past one), so these
  # execute the wrapper against fixture caches and assert stdout/exit/stderr.
  #
  # Chains mirror modules/nixos/homeManager/config.nix modelFallback.chains
  # (default + the four triage chains). If the config changes, update the
  # fixtures here — the test intentionally records the live chain shapes.
  suites."opencode-select-behaviour-tests" = {
    pos = __curPos;
    tests = [
      {
        name = "degrade-path-per-chain";
        type = "script";
        script = ''
          set -euo pipefail
          export PATH=${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.bash}/bin:$PATH
          wrap=${../modules/home/opencode/model-select.sh}
          prog=${../modules/home/opencode/model-select.jq}
          dir=$(mktemp -d)
          trap 'rm -rf "$dir"' EXIT

          # Live chain shapes from config.nix (evaluated by the nixtest
          # harness, NOT hand-copied — see realChains at the top of this
          # file; previously a jq -n literal that drifted from the config's
          # option-default expansion).
          cp ${chainsFile} "$dir/mf.json"
          goodcache="$dir/good.json"
          jq -n '{"usage":{"rolling":{"status":"ok","percent":4,"resetsAt":"2026-09-20T23:34:57.935Z"},"weekly":{"status":"ok","percent":3,"resetsAt":"2026-09-21T00:00:00.000Z"},"monthly":{"status":"ok","percent":94,"resetsAt":"2026-10-20T09:25:34.000Z"}}}' > "$goodcache"
          jq 'del(.usage.monthly)' "$goodcache" > "$dir/nomonth.json"
          jq '.usage.monthly.percent = "abc"' "$goodcache" > "$dir/badpct.json"
          printf 'not json at all' > "$dir/garbage.json"

          run() { # $1 = agent, $2 = cache file; writes rc/stdout/stderr in $dir
            local rc=0
            OPENCODE_SELECT_JQ="$prog" OPENCODE_SELECT_CONFIG="$dir/mf.json" \
              OPENCODE_SELECT_CACHE="$2" OPENCODE_SELECT_SLICE="$dir/none.json" \
              OPENCODE_SELECT_LOG="$dir/log.jsonl" OPENCODE_SELECT_ENSEMBLE="$dir/ens.json" \
              bash "$wrap" --agent "$1" > "$dir/stdout" 2> "$dir/stderr" || rc=$?
            printf '%s' "$rc" > "$dir/rc"
          }
          rc_of() { cat "$dir/rc"; }
          stdout_of() { cat "$dir/stdout"; }
          stderr_of() { cat "$dir/stderr"; }

          # default chain: cap-free tail -> degrade with exit 0 on every bad case.
          for cache in "$dir/nomonth.json" "$dir/badpct.json" "$dir/garbage.json"; do
            run default "$cache"
            [ "$(rc_of)" = "0" ] || { echo "FAIL default $cache: rc=$(rc_of)" >&2; exit 1; }
            [ "$(stdout_of)" = "opencode-go/ox-alpha-free" ] || { echo "FAIL default degrade stdout: $(stdout_of)" >&2; exit 1; }
            stderr_of | grep -qi 'falling back to last chain entry' \
              || { echo "FAIL default degrade warning missing: $(stderr_of)" >&2; exit 1; }
          done
          # missing cache file -> exit 3, no model, "missing usage cache".
          run default "$dir/nonexistent.json"
          [ "$(rc_of)" = "3" ] || { echo "FAIL default missing-cache: rc=$(rc_of)" >&2; exit 1; }
          [ -z "$(stdout_of)" ] || { echo "FAIL default missing-cache stdout not empty: $(stdout_of)" >&2; exit 1; }
          stderr_of | grep -q 'missing usage cache' || { echo "FAIL default missing-cache stderr: $(stderr_of)" >&2; exit 1; }

          # triage chains: blockedTerminal tail -> exit 5 + distinct BLOCKED msg.
          for agent in learning-promoter scout-skeptical qa-verification adversarial; do
            for cache in "$dir/nomonth.json" "$dir/badpct.json" "$dir/garbage.json"; do
              run "$agent" "$cache"
              [ "$(rc_of)" = "5" ] || { echo "FAIL $agent $cache: expected rc=5 got $(rc_of)" >&2; exit 1; }
              [ -z "$(stdout_of)" ] || { echo "FAIL $agent BLOCKED must print nothing on stdout: $(stdout_of)" >&2; exit 1; }
              stderr_of | grep -q 'has no cap-free terminal — BLOCKED' \
                || { echo "FAIL $agent BLOCKED stderr: $(stderr_of)" >&2; exit 1; }
            done
            run "$agent" "$dir/nonexistent.json"
            [ "$(rc_of)" = "3" ] || { echo "FAIL $agent missing-cache: rc=$(rc_of)" >&2; exit 1; }
          done

          echo "ok: degrade path per live chain (default degrades, triage blocks, missing cache rc=3)"
        '';
      }
      {
        name = "decision-log";
        type = "script";
        script = ''
                              set -euo pipefail
                              export PATH=${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.bash}/bin:${pkgs.diffutils}/bin:$PATH
                              wrap=${../modules/home/opencode/model-select.sh}
                              prog=${../modules/home/opencode/model-select.jq}
                              dir=$(mktemp -d)
                              trap 'rm -rf "$dir"' EXIT

          # Real default chain from config.nix (evaluated by the harness,
                              # not hand-copied). Whole payload written; --agent default reads
                              # .chains.default.
                              cp ${chainsFile} "$dir/mf.json"
                              jq -n '{"usage":{"rolling":{"status":"ok","percent":4,"resetsAt":"2026-09-20T23:34:57.935Z"},"weekly":{"status":"ok","percent":3,"resetsAt":"2026-09-21T00:00:00.000Z"},"monthly":{"status":"ok","percent":94,"resetsAt":"2026-10-20T09:25:34.000Z"}}}' > "$dir/cache.json"

                              export OPENCODE_SELECT_JQ="$prog" OPENCODE_SELECT_CONFIG="$dir/mf.json" \
                                OPENCODE_SELECT_CACHE="$dir/cache.json" OPENCODE_SELECT_SLICE="$dir/none.json" \
                                OPENCODE_SELECT_LOG="$dir/log.jsonl" OPENCODE_SELECT_ENSEMBLE="$dir/ens.json"

                              # Usable run: monthly 94 > deepseek static cap 90 -> skipped by static,
                              # mimo chosen. The log line must contain the expected skipped entry.
                              out=$(bash "$wrap" --agent default)
                              [ "$out" = "opencode-go/mimo-v2.5" ] || { echo "FAIL: won model (got: $out)" >&2; exit 1; }
                              [ -s "$dir/log.jsonl" ] || { echo "FAIL: no log line written" >&2; exit 1; }
                              jq -e '(.chosen == "opencode-go/mimo-v2.5")
                                  and (.agent == "default")
                                  and (.degraded == false)
                                  and (.skipped | length) == 1
                                  and (.skipped[0].model == "opencode-go/deepseek-v4-flash")
                                  and (.skipped[0].window == "monthly")
                                  and (.skipped[0].used == 94)
                                  and (.skipped[0].cap == 90)
                                  and (.skipped[0].by == "static")
                                  and (.ts | type) == "number"' "$dir/log.jsonl" \
                                || { echo "FAIL: log line malformed: $(cat "$dir/log.jsonl")" >&2; exit 1; }

                              # Unwritable log path: stdout and exit code must be unchanged.
                              mkdir -p "$dir/ro" && chmod 555 "$dir/ro"
                              out2=$(OPENCODE_SELECT_LOG="$dir/ro/log.jsonl" bash "$wrap" --agent default 2>/dev/null || echo "RC=$?")
                              case "$out2" in
                                "opencode-go/mimo-v2.5") : ;;
                                *) echo "FAIL: unwritable log changed behaviour (got: $out2)" >&2; exit 1 ;;
                              esac
                              [ ! -e "$dir/ro/log.jsonl" ] || { echo "FAIL: unwritable log should not exist" >&2; exit 1; }

                              # ── Log trim ────────────────────────────────────────────────────────
                              # Seed 2510 valid JSONL lines, run one resolution, and assert the
                              # file is trimmed back to LOG_CAP (2000): newest lines kept, file
                              # still valid JSONL, resolution line present as the newest entry.
                              biglog="$dir/big.jsonl"
                              : > "$biglog"
                              i=0
                              while [ "$i" -lt 2510 ]; do
                                printf '{"ts":%s,"agent":"seed-%s","chosen":"m/seed","skipped":[],"degraded":false}\n' "$i" "$i" >> "$biglog"
                                i=$((i + 1))
                              done
                              [ "$(wc -l < "$biglog")" = "2510" ] || { echo "FAIL: seeding big log" >&2; exit 1; }

                              out3=$(OPENCODE_SELECT_LOG="$biglog" bash "$wrap" --agent default 2>/dev/null || echo "RC=$?")
                              case "$out3" in
                                "opencode-go/mimo-v2.5") : ;;
                                *) echo "FAIL: log trim changed stdout (got: $out3)" >&2; exit 1 ;;
                              esac

                              n=$(wc -l < "$biglog")
                              [ "$n" -eq "2000" ] || {
                                echo "FAIL: log not trimmed to LOG_CAP 2000 (got $n lines)" >&2; exit 1
                              }
                              # All remaining lines must still be valid JSONL.
                              jq -e 'type == "object"' "$biglog" >/dev/null 2>&1 \
                                || { echo "FAIL: trimmed log not valid JSONL: $(head -c 200 "$biglog")" >&2; exit 1; }
                              # The newest resolution line must be the last line.
                              last1=$(tail -n 1 "$biglog")
                              printf '%s' "$last1" | jq -e '.agent == "default" and .chosen == "opencode-go/mimo-v2.5"' >/dev/null \
                                || { echo "FAIL: newest resolution not kept as last line (got: $last1)" >&2; exit 1; }

                              # Read-only LOG_FILE: append + trim both fail silently; stdout and
                              # exit code must be unchanged, and the file must stay byte-identical.
                              rolog="$dir/rotrim.jsonl"
                              cp "$biglog" "$rolog"
                              chmod 444 "$rolog"
                              before=$(sha256sum "$rolog" | cut -d' ' -f1)
                              out4=$(OPENCODE_SELECT_LOG="$rolog" bash "$wrap" --agent default 2>/dev/null || echo "RC=$?")
                              case "$out4" in
                                "opencode-go/mimo-v2.5") : ;;
                                *) echo "FAIL: read-only log changed stdout (got: $out4)" >&2; exit 1 ;;
                              esac
                              after=$(sha256sum "$rolog" | cut -d' ' -f1)
                              [ "$before" = "$after" ] || { echo "FAIL: read-only log file mutated" >&2; exit 1; }

                              echo "ok: decision log line written with expected skipped entry; unwritable log is inert; trim keeps newest; read-only log is inert"
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
        # the poll. SOURCE-LEVEL by necessity: the poll unit is a
        # writeShellApplication derivation generated inside a full home-manager
        # eval (needs the module graph + a live API key + network), which a
        # nixtest cannot build — so there is no behavioural test possible here.
        # model-select.sh, by contrast, is extracted standalone and IS tested
        # behaviourally (opencode-select-behaviour-tests suite).
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
