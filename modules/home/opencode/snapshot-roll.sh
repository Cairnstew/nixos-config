#!/usr/bin/env bash
# Snapshot-roll logic for budget pacing (usage.nix "budget mode").
#
# Keeps ~/.cache/opencode/go-usage-slices.json fresh for the model selector's
# budget pacing. The slice snapshot records, per window, the usage percent at
# the START of the current slice; on each poll a NEW snapshot starts when the
# current slice has ended (now >= sliceStart + sliceHours), when the cache's
# resetsAt differs from the snapshot's (period reset), or when there is no
# snapshot; otherwise the existing snapshot is preserved byte-for-byte.
#
# Usage: opencode-go-slices-roll <cache-json> <slice-file> [slice-hours] [now]
#   cache-json   full Go usage API response (must have .usage.monthly)
#   slice-file   destination file (written atomically via tmp + mv)
#   slice-hours  slice length for the monthly window (default 24)
#   now          unix seconds for the poll (default: current time)
#
# Degrade-safety: never writes partial/invalid JSON. If the existing snapshot
# cannot be parsed it is replaced with a fresh one. Any failure here must not
# affect the usage cache write (the caller runs it after the cache write).
set -euo pipefail

cache_json="$1"
slice_file="$2"
slice_hours="${3:-24}"
now="${4:-$(date +%s)}"

cache_reset=$(printf '%s' "$cache_json" | jq -er '.usage.monthly.resetsAt')
cache_pct=$(printf '%s' "$cache_json" | jq -er '.usage.monthly.percent')

snapshot=""
if [ -r "$slice_file" ]; then
  if cur=$(cat "$slice_file") && \
     printf '%s' "$cur" | jq -e '.monthly.sliceStart != null and .monthly.usageAtStart != null and .monthly.resetsAt != null' >/dev/null 2>&1; then
    snap_reset=$(printf '%s' "$cur" | jq -r '.monthly.resetsAt')
    snap_start=$(printf '%s' "$cur" | jq -r '.monthly.sliceStart')
    roll=0
    [ "$cache_reset" != "$snap_reset" ] && roll=1
    [ "$now" -ge "$((snap_start + slice_hours * 3600))" ] && roll=1
    if [ "$roll" -eq 0 ]; then
      snapshot="$cur"
    fi
  fi
fi

if [ -z "$snapshot" ]; then
  snapshot=$(jq -cn \
    --argjson now "$now" \
    --arg resetsAt "$cache_reset" \
    --argjson usageAtStart "$cache_pct" \
    '{ monthly: { sliceStart: $now, usageAtStart: $usageAtStart, resetsAt: $resetsAt } }')
fi

# Validate + atomic write; never leave a partial file behind.
printf '%s' "$snapshot" | jq -e '.monthly.sliceStart != null and .monthly.usageAtStart != null and .monthly.resetsAt != null' >/dev/null
mkdir -p "$(dirname "$slice_file")"
printf '%s' "$snapshot" > "${slice_file}.tmp"
mv "${slice_file}.tmp" "$slice_file"