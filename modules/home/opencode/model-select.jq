# Pure jq resolution program for opencode-model-select.
# Used by modules/home/opencode/fallback.nix (loaded at runtime via 'jq -f').
# Input:  the Go usage snapshot ({ usage: { rolling|weekly|monthly: ... } })
# Args:   --argjson chain <ordered chain array>   --argjson now <unix seconds>
# Output: the first eligible entry model id, or nothing.

    . as $doc
    | ($doc.usage.weekly.resetsAt | sub("[.][0-9]+Z$"; "Z") | fromdateiso8601) as $wEnd
    | ($doc.usage.monthly.resetsAt | sub("[.][0-9]+Z$"; "Z") | fromdateiso8601) as $mEnd
    | def paceCap(entry; winEnd; periodSecs):
        ((((($now - (winEnd - periodSecs)) / periodSecs) * 100)
           | (if . < 0 then 0 elif . > 100 then 100 else . end)) as $elPct
        | if $elPct < (entry.pacing.floor // 5) then null
          else ([($elPct + (entry.pacing.buffer // 10)), 100] | min)
          end);
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
