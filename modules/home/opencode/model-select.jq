# Pure jq resolution program for `opencode-model-select` (used by
# modules/home/opencode/fallback.nix and the nixtest suite
# tests/opencode-model-fallback_test.nix — one source of truth so the tests
# exercise the exact bytes the selector runs).
#
# Input:  the Go usage snapshot ({ usage: { rolling|weekly|monthly: ... } })
# Args:   --argjson chain <ordered chain array>
#         --argjson now <unix seconds>
#         --argjson snapshot <slice snapshot object | null>   (optional)
# Output: the first eligible entry model id, or nothing.
#
# Semantics (README "Model fallback" section):
#   - Eligible = rolling cap AND weekly cap AND monthly cap. A window cap
#     passes iff its STATIC cap is null-or-satisfied AND — only for entries
#     with pacing.enable = true — usage is within the window's pace term. The
#     pace term is NULL/inert when the flag is false or absent.
#   - Two pacing modes (entry.pacing.mode, default "elapsed"):
#       "elapsed" — paceCap = min(100, elapsedPercent + buffer), inert below
#         floor. Weekly periodStart = resetsAt - 7d (exact; calendar-aligned
#         Monday 00:00 UTC — rollover observed verbatim 2026-08-31T00:00:00Z).
#         Monthly = resetsAt - 30d: a FIXED 30-day window anchored at
#         2026-09-20T09:25:34Z (both weekly rollover and monthly reset
#         observed). Re-confirm at the 2026-10-20 reset; next expected
#         2026-11-19T09:25:34Z.
#       "budget" — budgetCap = usageAtStart + (100 - usageAtStart)/slicesLeft
#         where slicesLeft = ceil((winEnd - sliceStart)/sliceLen). Divvies the
#         usage LEFT in a fixed window over the slices LEFT (monthly only by
#         default, entry.pacing.budget.windows). Slice-boundary ratchet:
#         unspent budget rolls forward, overspend spreads over remaining
#         slices. The snapshot arg is the /state file written by
#         usage.nix (go-usage-slices.json). Degrades silently to static caps
#         when the snapshot is missing/stale (>2 slices old)/period-mismatched;
#         never errors because of the snapshot.
#   - BUG FIX 2026-08-26 (self-improve-usage Tier 1 Task 2, findings §2c):
#     the pace term previously consulted entry.pacing.floor/buffer but NEVER
#     entry.pacing.enable, so entries shipped with enable=false were paced
#     anyway. Symptom signature if this class of bug recurs elsewhere: a
#     whole chain resolves BLOCKED (exit 5) while ROLLING sits at ~0% and
#     every static cap passes.
#   - Rolling never consults pacing fields (trailing 5h sliding window).
#   - NOTE: `. as $doc` is required because inside select() the current
#     input is the chain ENTRY — a bare `.usage` there would be null, and
#     jq treats any number >= null as true, silently disabling every cap
#     (bug #4 class).
#   - REPORT MODE (--argjson report true): the wrapper requests the full
#     decision for the decision log. Output becomes
#       { "winner": <model|"">, "skipped": [ {model, window, used, cap, by} ] }
#     where `skipped` lists every FAILED window of every entry before the
#     winner (or of every entry when no winner). cap = the effective cap
#     min(static, pace); by = which cap bound ("static" or "pace") — used to
#     tune pacing from real data. Without --argjson report the program emits
#     the winning model id (or nothing) exactly as before.
  . as $doc
| ($doc.usage.weekly.resetsAt | sub("[.][0-9]+Z$"; "Z") | fromdateiso8601) as $wEnd
| ($doc.usage.monthly.resetsAt | sub("[.][0-9]+Z$"; "Z") | fromdateiso8601) as $mEnd
| ($ARGS.named.snapshot // null) as $snapshot
| def paceCap(entry; winEnd; periodSecs):
    if ((entry.pacing.enable // false) | not) then null
    else
      ((((($now - (winEnd - periodSecs)) / periodSecs) * 100)
         | (if . < 0 then 0 elif . > 100 then 100 else . end)) as $elPct
      | if $elPct < (entry.pacing.floor // 5) then null
        else ([($elPct + (entry.pacing.buffer // 10)), 100] | min)
        end)
    end;
  def budgetCap(entry; winName; winEnd; sliceLen):
    try (
      if ((entry.pacing.enable // false) | not) then null
      elif ((entry.pacing.mode // "elapsed") != "budget") then null
      elif ((((entry.pacing.budget.windows // ["monthly"]) | index(winName)) == null)) then null
      elif ($snapshot == null) or ($snapshot[winName] == null) then null
      else
        ($snapshot[winName]) as $snap
        | ($snap.sliceStart) as $sliceStart
        | ($snap.usageAtStart) as $usageAtStart
        | (try (($snap.resetsAt | sub("[.][0-9]+Z$"; "Z") | fromdateiso8601)) catch null) as $snapEnd
        | if (($sliceStart == null) or ($usageAtStart == null) or ($snapEnd == null)) then null
          elif (($now - $sliceStart) > (2 * sliceLen)) then null
          elif ($snapEnd != winEnd) then null
          else
            ((((winEnd - $sliceStart) / sliceLen) | ceil)) as $slicesLeft
            | if ($slicesLeft <= 0) then 100
              else ($usageAtStart + ((100 - $usageAtStart) / $slicesLeft)) end
          end
      end
    ) catch null;
  def windowPaceCap(e; winEnd; periodSecs; winName; sliceLen):
    if ((e.pacing.enable // false) | not) then null
    elif ((e.pacing.mode // "elapsed") == "budget")
      then budgetCap(e; winName; winEnd; sliceLen)
    else paceCap(e; winEnd; periodSecs) end;
  # wCap: window evaluation with the per-window decision for the report.
  # Eligibility is EXACTLY windowOk (static AND pace must both pass); cap and
  # by are reporting only and never participate in the decision.
  def wCap(e; staticField; usagePct; winEnd; periodSecs; winName; sliceLen):
    (e[staticField]) as $staticCap
    | (windowPaceCap(e; winEnd; periodSecs; winName; sliceLen)) as $pc
    | (($staticCap == null) or ($staticCap >= usagePct)) as $staticOk
    | (($pc == null) or (usagePct <= $pc)) as $paceOk
    | ($staticCap // 100) as $staticEff
    | ($pc // 100) as $paceEff
    | (if $staticEff <= $paceEff
       then { cap: $staticEff, by: "static" }
       else { cap: $paceEff, by: "pace" } end) as $bind
    | { ok: ($staticOk and $paceOk), used: usagePct } + $bind;
  def rollingCap(e; usagePct):
    (e.maxRollingPercent) as $r
    | { ok: (($r == null) or ($r >= usagePct))
      , used: usagePct, cap: ($r // 100), by: "static" };
  ([$chain[]
    | (.model // null) as $m
    | if $m == null then { model: null, ok: false, fails: [] }
      else
        (rollingCap(.; $doc.usage.rolling.percent)) as $dr
        | (wCap(.; "maxWeeklyPercent"; $doc.usage.weekly.percent; $wEnd; 604800; "weekly"; ( .pacing.budget.sliceHours // 24 ) * 3600)) as $dw
        | (wCap(.; "maxMonthlyPercent"; $doc.usage.monthly.percent; $mEnd; 2592000; "monthly"; ( .pacing.budget.sliceHours // 24 ) * 3600)) as $dm
        | { model: $m
          , ok: ($dr.ok and $dw.ok and $dm.ok)
          , fails: (if $dr.ok then [] else [($dr | {window: "rolling", used, cap, by})] end)
                   + (if $dw.ok then [] else [($dw | {window: "weekly", used, cap, by})] end)
                   + (if $dm.ok then [] else [($dm | {window: "monthly", used, cap, by})] end)
          }
      end]) as $E
| ([$E[].ok] | index(true)) as $winIdx
| (if $winIdx == null then ($E | length) else $winIdx end) as $probeEnd
| ([range(0; $probeEnd) as $i | $E[$i].fails[] | {model: $E[$i].model} + .]) as $skipped
| (if $winIdx == null then null else $E[$winIdx].model end) as $winner
| if ($ARGS.named.report == true)
  then { winner: ($winner // ""), skipped: $skipped }
  else ($winner) // empty
  end
