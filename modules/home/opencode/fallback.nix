# Usage-aware model fallback for opencode agents.
#
# Ships:
#   - `opencode-model-select`  selector CLI (resolve + optional ensemble sync)
#   - ~/.config/opencode/model-fallback.json   chains config consumed by it
#
# Design (Tier 0 findings, /tmp/opencode/model-fallback/tier0-findings.md):
#   - The OpenCode Go usage API exposes ONLY status/percent/resetsAt per
#     window (rolling ~5h, weekly, monthly) — no dollar amounts — so chain
#     caps are percent-based by construction.
#   - Lever (i): the `opencode` wrapper injects --model from the selector.
#   - Lever (ii): the selector rewrites <repoDir>/.opencode/ensemble.json
#     (project-level override wins over the HM global per the ensemble
#     plugin's src/config.ts merge order). The plugin reads that file ONCE
#     per opencode process start, so this MUST run before dispatch.

{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf;

  cfg = config.my.programs.opencode;

  # Chains rendered to a JSON file at a stable path. Read-only is fine: it is
  # pure Nix config; only the RESOLVED winners go into mutable files.
  fallbackConfigFile = ".config/opencode/model-fallback.json";

  # jq filter: input is the cache file { usage: {...} }; $chain is the ordered
  # chain array. NOTE: `. as $doc` is required because inside select() the
  # current input is the chain ENTRY — a bare `.usage` there would be null,
  # and jq treats any number >= null as true, silently disabling every cap.
  resolveJq = ''
    . as $doc
    | def eligible(entry):
        ((entry.maxRollingPercent == null) or (entry.maxRollingPercent >= $doc.usage.rolling.percent))
        and ((entry.maxWeeklyPercent == null) or (entry.maxWeeklyPercent >= $doc.usage.weekly.percent))
        and ((entry.maxMonthlyPercent == null) or (entry.maxMonthlyPercent >= $doc.usage.monthly.percent));
    [$chain[] | select(eligible(.))] | (.[0].model) // empty
  '';
in
{
  # ── Chains config → ~/.config/opencode/model-fallback.json ────────────────
  # NOTE: fallbackConfigFile already begins with ".config/", so no extra dot.
  home.file."${fallbackConfigFile}" = mkIf (cfg.modelFallback.chains != { }) {
    text = builtins.toJSON { inherit (cfg.modelFallback) chains; };
  };

  # ── The selector CLI ───────────────────────────────────────────────────────
  home.packages = mkIf (cfg.modelFallback.chains != { }) [
    (pkgs.writeShellScriptBin "opencode-model-select" ''
      set -euo pipefail
      export PATH="${pkgs.jq}/bin:${pkgs.coreutils}/bin:$PATH"

      FALLBACK_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/opencode/model-fallback.json"
      CACHE_FILE="${cfg.modelFallback.cacheFile}"
      ENSEMBLE_PROJECT="${cfg.modelFallback.repoDir}/.opencode/ensemble.json"

      usage() {
        cat <<'USAGE'
usage: opencode-model-select [--agent NAME] [--sync-ensemble]
  Resolves the winning model for an agent from the cached Go usage snapshot
  and the configured modelFallback chains. Prints the model id on stdout.
  --agent NAME        use chains[NAME], falling back to chains.default
  --sync-ensemble     additionally rewrite ${cfg.modelFallback.repoDir}/.opencode/ensemble.json
                      with modelsByAgent resolved for EVERY configured agent
                      (must run BEFORE the opencode process starts)
USAGE
      }

      agent=""
      sync=0
      while [ $# -gt 0 ]; do
        case "$1" in
          --agent) agent="''$2"; shift 2 ;;
          --sync-ensemble) sync=1; shift ;;
          -h|--help) usage; exit 0 ;;
          *) echo "opencode-model-select: unknown arg $1" >&2; usage >&2; exit 2 ;;
        esac
      done

      [ -r "$FALLBACK_CONFIG" ] || { echo "opencode-model-select: missing $FALLBACK_CONFIG" >&2; exit 3; }
      [ -r "$CACHE_FILE" ] || { echo "opencode-model-select: missing usage cache $CACHE_FILE" >&2; exit 3; }

      # Resolve one chain (JSON array in $1) against the usage snapshot.
      # NOTE: the program is single-quoted so bash never expands $doc/$chain;
      # it contains no apostrophes by construction.
      resolve_chain() {
        jq -re '${resolveJq}' --argjson chain "$1" "$CACHE_FILE" 2>/dev/null || true
      }

      # Last entry of a chain is the always-eligible safety net by convention;
      # an exhausted chain degrades to it instead of failing hard.
      last_model_of_chain() {
        jq -rn '. | last | .model' <<< "$1"
      }

      resolve_for_agent() { # $1 = agent name; empty means default chain
        local key="$1" chain winner
        if [ -n "$key" ]; then
          chain=$(jq -c --arg k "$key" '.chains[$k] // .chains.default // empty' "$FALLBACK_CONFIG")
        else
          chain=$(jq -c '.chains.default // empty' "$FALLBACK_CONFIG")
        fi
        [ -n "$chain" ] || return 1
        winner=$(resolve_chain "$chain")
        if [ -z "$winner" ]; then
          winner=$(last_model_of_chain "$chain")
        fi
        [ -n "$winner" ] && printf '%s' "$winner"
      }

      if [ "$sync" -eq 0 ]; then
        m=$(resolve_for_agent "$agent")
        if [ -z "$m" ]; then
          echo "opencode-model-select: no resolvable chain for agent=''${agent:-default}" >&2
          exit 4
        fi
        printf '%s\n' "$m"
        exit 0
      fi

      # --sync-ensemble: resolve every configured agent and write the project
      # override atomically, preserving unrelated keys already in the file.
      models_by_agent='{}'
      while IFS= read -r key; do
        [ "$key" = "default" ] && continue
        if m=$(resolve_for_agent "$key"); then
          models_by_agent=$(jq -cn --argjson acc "$models_by_agent" --arg k "$key" --arg m "$m" '$acc + { ($k): $m }')
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
    '')
  ];
}
