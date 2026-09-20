# Pure jq resolution program for `opencode-model-select` (used by
# modules/home/opencode/fallback.nix and the nixtest suite
# tests/opencode-model-fallback_test.nix — one source of truth so the tests
# exercise the exact bytes the selector runs).
#
# Input:  the Go usage snapshot ({ usage: { rolling|weekly|monthly: ... } })
# Args:   --argjson chain <ordered chain array>   --argjson now <unix seconds>
# Output: the first eligible entry model id, or nothing.
#
# Semantics (README "Model fallback" section):
#   - Eligible = rolling cap AND weekly cap AND monthly cap. A window cap
#     passes iff its STATIC cap is null-or-satisfied AND — only for entries
#     with pacing.enable = true — usage is within paceCap. The pace term is
#     NULL/inert when the flag is false or absent.
#   - BUG FIX 2026-08-26 (self-improve-usage Tier 1 Task 2, findings §2c):
#     paceCap previously consulted entry.pacing.floor/buffer but NEVER
#     entry.pacing.enable, so entries shipped with enable=false were paced
#     anyway. Symptom signature if this class of bug recurs elsewhere: a
#     whole chain resolves BLOCKED (exit 5) while ROLLING sits at ~0% and
#     every static cap passes.
#   - paceCap = min(100, elapsedPercent + buffer), inert below floor.
#     Weekly periodStart = resetsAt - 7d (exact; calendar-aligned Monday
#     00:00 UTC — rollover observed verbatim 2026-08-31T00:00:00Z).
#     Monthly = resetsAt - 30d: a FIXED 30-day window anchored at
#     2026-09-20T09:25:34Z (both weekly rollover and monthly reset observed).
#     Re-confirm at the 2026-10-20 reset; next expected 2026-11-19T09:25:34Z.
#   - Rolling never consults pacing fields (trailing 5h sliding window).
#   - NOTE: `. as $doc` is required because inside select() the current
#     input is the chain ENTRY — a bare `.usage` there would be null, and
#     jq treats any number >= null as true, silently disabling every cap
#     (bug #4 class).
  . as $doc
| ($doc.usage.weekly.resetsAt | sub("[.][0-9]+Z$"; "Z") | fromdateiso8601) as $wEnd
| ($doc.usage.monthly.resetsAt | sub("[.][0-9]+Z$"; "Z") | fromdateiso8601) as $mEnd
| def paceCap(entry; winEnd; periodSecs):
    if ((entry.pacing.enable // false) | not) then null
    else
      ((((($now - (winEnd - periodSecs)) / periodSecs) * 100)
         | (if . < 0 then 0 elif . > 100 then 100 else . end)) as $elPct
      | if $elPct < (entry.pacing.floor // 5) then null
        else ([($elPct + (entry.pacing.buffer // 10)), 100] | min)
        end)
    end;
  def windowOk(e; staticField; usagePct; winEnd; periodSecs):
    (e[staticField]) as $staticCap
    | ($staticCap == null)
      or (($staticCap >= usagePct)
          and ((paceCap(e; winEnd; periodSecs)) as $pc
               | ($pc == null) or (usagePct <= $pc)));
  [$chain[]
   | select((.model != null)
            and (windowOk(.; "maxWeeklyPercent"; $doc.usage.weekly.percent; $wEnd; 604800))
            and (windowOk(.; "maxMonthlyPercent"; $doc.usage.monthly.percent; $mEnd; 2592000))
            and ((.maxRollingPercent == null)
                 or (.maxRollingPercent >= $doc.usage.rolling.percent)))]
  | (.[0].model) // empty
