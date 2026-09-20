#!/usr/bin/env bash
# model-select.sh — core of `opencode-model-select` (the selector CLI).
#
# Env-parameterized so the nixtest suite runs the EXACT bytes the deployed
# wrapper runs. fallback.nix wraps this script with baked defaults:
#
#   OPENCODE_SELECT_JQ      store path of model-select.jq (required)
#   OPENCODE_SELECT_CONFIG  model-fallback.json (chains config)
#   OPENCODE_SELECT_CACHE   go-usage.json      (usage cache)
#   OPENCODE_SELECT_SLICE   go-usage-slices.json (budget slice snapshot)
#   OPENCODE_SELECT_LOG     model-select.log   (decision log)
#   OPENCODE_SELECT_ENSEMBLE <repo>/.opencode/ensemble.json
#
# Exit codes: 0 resolved (model id on stdout); 3 missing config/cache;
# 4 no chain configured for the agent; 5 chain blocked (no cap-free terminal
# with unusable/exhausted usage) — callers must treat 5 as "do not dispatch".
set -euo pipefail

: "${OPENCODE_SELECT_JQ:?OPENCODE_SELECT_JQ must point at model-select.jq}"
FALLBACK_CONFIG="${OPENCODE_SELECT_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/model-fallback.json}"
CACHE_FILE="${OPENCODE_SELECT_CACHE:-$HOME/.cache/opencode/go-usage.json}"
SLICE_FILE="${OPENCODE_SELECT_SLICE:-$HOME/.cache/opencode/go-usage-slices.json}"
LOG_FILE="${OPENCODE_SELECT_LOG:-$HOME/.cache/opencode/model-select.log}"
ENSEMBLE_PROJECT="${OPENCODE_SELECT_ENSEMBLE:-$HOME/nixos-config/.opencode/ensemble.json}"

# Rough cap on the decision log: trim in batches (only when far over), not per write.
LOG_CAP=2000
LOG_TRIM=2500

usage() {
  cat <<'USAGE'
usage: opencode-model-select [--agent NAME] [--sync-ensemble]
  Resolves the winning model for an agent from the cached Go usage snapshot
  and the configured modelFallback chains. Prints the model id on stdout.
  --agent NAME        use chains[NAME], falling back to chains.default
  --sync-ensemble     additionally rewrite the project .opencode/ensemble.json
                      with modelsByAgent resolved for EVERY configured agent
                      (must run BEFORE the opencode process starts)

Exit codes: 0 resolved (model id on stdout); 3 missing config/cache;
4 no chain configured for the agent; 5 chain blocked (usage data unusable, or
exhausted, with no cap-free terminal) — callers must treat this as
"do not dispatch", not an error to retry.
USAGE
}

agent=""
sync=0
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) agent="$2"; shift 2 ;;
    --sync-ensemble) sync=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "opencode-model-select: unknown arg $1" >&2; usage >&2; exit 2 ;;
  esac
done

[ -r "$FALLBACK_CONFIG" ] || { echo "opencode-model-select: missing $FALLBACK_CONFIG" >&2; exit 3; }
[ -r "$CACHE_FILE" ] || { echo "opencode-model-select: missing usage cache $CACHE_FILE" >&2; exit 3; }

# Classify unusable usage data up front. "Unusable" = any window missing or any
# percent not a number — the jq program would error on it (and every error is
# swallowed, silently). The wrapper decides degrade-vs-block from the chain tail.
UNUSABLE=0
UNUSABLE_WHY="usage data unusable"
if ! jq -e '
    (.usage.rolling and (.usage.rolling.percent | type) == "number")
    and (.usage.weekly and (.usage.weekly.percent | type) == "number")
    and (.usage.monthly and (.usage.monthly.percent | type) == "number")
' "$CACHE_FILE" >/dev/null 2>&1; then
  UNUSABLE=1
  if ! jq -e '.usage.monthly' "$CACHE_FILE" >/dev/null 2>&1; then
    UNUSABLE_WHY="usage.monthly missing"
  elif ! jq -e '(.usage.monthly.percent | type) == "number"' "$CACHE_FILE" >/dev/null 2>&1; then
    UNUSABLE_WHY="usage.monthly.percent not a number"
  fi
fi

# Last entry of a chain is the always-eligible safety net by convention. Degrade
# to it ONLY when it is cap-free (model set, no static caps). A blockedTerminal
# marker (model null) or a capped tail must surface as BLOCKED (exit 5) instead
# of running a paid model with no cap enforcement.
last_model_of_chain() {
  jq -r '. | last | (.model // empty)' <<< "$1"
}

last_is_capfree() {
  jq -e '. | last | (.model != null)
    and (.maxRollingPercent == null) and (.maxWeeklyPercent == null)
    and (.maxMonthlyPercent == null)' <<< "$1" >/dev/null 2>&1
}

# Append one JSON line per resolution. Never fail or slow the selector; cap the
# file by trimming in batches. No secrets (model ids + percents only).
log_resolution() { # $1 agent label, $2 chosen ("" when blocked), $3 skipped JSON array, $4 degraded 0/1
  local line n degraded_json
  if [ "$4" = "1" ]; then degraded_json=true; else degraded_json=false; fi
  line=$(jq -cn \
    --argjson ts "$(date +%s)" \
    --arg agent "$1" \
    --arg chosen "$2" \
    --argjson skipped "$3" \
    --argjson degraded "$degraded_json" \
    '{ts: $ts, agent: $agent, chosen: $chosen, skipped: $skipped, degraded: $degraded}')
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  if printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null; then
    n=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "${n:-0}" -gt "$LOG_TRIM" ] 2>/dev/null; then
      tail -n "$LOG_CAP" "$LOG_FILE" > "${LOG_FILE}.tmp" 2>/dev/null \
        && mv "${LOG_FILE}.tmp" "$LOG_FILE" 2>/dev/null || true
    fi
  fi
  return 0
}

# Resolve one chain (JSON array in $1) against the usage snapshot, printing the
# full report {"winner": <model|"">, "skipped": [..]}. The program is loaded with
# -f from its store path (interpolating it into a shell string silently broke on
# apostrophes — 2026-08-26). NOW supplies the selector's own clock; SNAPSHOT the
# budget slice snapshot ('null' when missing => budget skipped).
resolve_chain() { # $1 = chain JSON
  local now snapshot
  now=$(date +%s)
  if [ -r "$SLICE_FILE" ]; then
    snapshot=$(cat "$SLICE_FILE")
  else
    snapshot='null'
  fi
  jq -re -f "$OPENCODE_SELECT_JQ" --argjson chain "$1" --argjson now "$now" \
    --argjson snapshot "$snapshot" --argjson report true "$CACHE_FILE" 2>/dev/null || true
}

resolve_for_agent() { # $1 = agent name; empty means default chain
  local key="$1" chain report winner skipped degraded=0
  if [ -n "$key" ]; then
    chain=$(jq -c --arg k "$key" '.chains[$k] // .chains.default // empty' "$FALLBACK_CONFIG")
  else
    chain=$(jq -c '.chains.default // empty' "$FALLBACK_CONFIG")
  fi
  [ -n "$chain" ] || return 1

  if [ "$UNUSABLE" -eq 1 ]; then
    if last_is_capfree "$chain"; then
      winner=$(last_model_of_chain "$chain")
      echo "opencode-model-select: ${UNUSABLE_WHY}, falling back to last chain entry" >&2
      log_resolution "${key:-default}" "$winner" '[]' 1
      printf '%s' "$winner"
      return 0
    fi
    # BlockedTerminal tail, or a capped tail with no data: dispatching would run
    # a paid model with no enforcement — exit 5 (same as exhausted), distinct msg.
    echo "opencode-model-select: ${UNUSABLE_WHY} and chain for agent='${key:-default}' has no cap-free terminal — BLOCKED" >&2
    log_resolution "${key:-default}" "" '[]' 1
    exit 5
  fi

  report=$(resolve_chain "$chain")
  winner=$(printf '%s' "$report" | jq -r '.winner // empty' 2>/dev/null)
  skipped=$(printf '%s' "$report" | jq -c '.skipped // []' 2>/dev/null)
  if [ -z "$winner" ]; then
    if last_is_capfree "$chain"; then
      winner=$(last_model_of_chain "$chain")
      degraded=1
      echo "opencode-model-select: chain for agent='${key:-default}' exhausted; degrading to last cap-free entry" >&2
    else
      # NOTE: report $key (this function's argument), not the CLI-level $agent —
      # during --sync-ensemble the CLI var is empty and every per-agent BLOCKED
      # used to mislabel itself as "agent=default" (caught 2026-08-26, Tier 1 Task 2).
      echo "opencode-model-select: chain for agent='${key:-default}' exhausted; no cap-free terminal — BLOCKED" >&2
      log_resolution "${key:-default}" "" "${skipped:-[]}" 1
      exit 5
    fi
  fi
  log_resolution "${key:-default}" "$winner" "${skipped:-[]}" "$degraded"
  [ -n "$winner" ] && printf '%s' "$winner"
}

if [ "$sync" -eq 0 ]; then
  m=$(resolve_for_agent "$agent")
  if [ -z "$m" ]; then
    echo "opencode-model-select: no resolvable chain for agent='${agent:-default}'" >&2
    exit 4
  fi
  printf '%s\n' "$m"
  exit 0
fi

# --sync-ensemble: resolve every configured agent and write the project override
# atomically, preserving unrelated keys already in the file. NOTE: a BLOCKED/
# unresolvable agent is skipped and its PREVIOUS modelsByAgent entry is left in
# place — the file cannot distinguish fresh-resolved from carried-over entries.
models_by_agent='{}'
while IFS= read -r key; do
  [ "$key" = "default" ] && continue
  if m=$(resolve_for_agent "$key"); then
    models_by_agent=$(jq -cn --argjson acc "$models_by_agent" --arg k "$key" --arg m "$m" '$acc + { ($k): $m }')
  else
    echo "opencode-model-select: agent '$key' has no eligible model (rc=$?) — keeping its existing modelsByAgent entry unchanged" >&2
  fi
done < <(jq -r '.chains | keys[]' "$FALLBACK_CONFIG")

mkdir -p "$(dirname "$ENSEMBLE_PROJECT")"
tmp=$(mktemp "$(dirname "$ENSEMBLE_PROJECT")/.ensemble.json.tmp.XXXXXX")
trap 'rm -f "$tmp"' EXIT

if [ -r "$ENSEMBLE_PROJECT" ]; then base=$(cat "$ENSEMBLE_PROJECT"); else base='{}'; fi
jq -s '.[0] * { modelsByAgent: ((.[0].modelsByAgent // {}) * $mba) }' \
  --argjson mba "$models_by_agent" \
  <(echo "$base") <(printf '{"modelsByAgent":%s}' "$models_by_agent") > "$tmp"
mv "$tmp" "$ENSEMBLE_PROJECT"
trap - EXIT
echo "opencode-model-select: synced $ENSEMBLE_PROJECT ($(jq -r '.modelsByAgent | length' "$ENSEMBLE_PROJECT") agents)" >&2