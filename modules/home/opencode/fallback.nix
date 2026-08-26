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

  # Guard (Tier 1, decision D1): pacing applies ONLY to weekly/monthly — the
  # rolling window is a trailing 5h sliding window with no fixed anchor
  # (/tmp/opencode/model-fallback-pacing/tier0-findings.md §1), so enabling
  # pacing on an entry that constrains only rolling would silently do nothing.
  # Fail evaluation instead.
  pacingWithoutPacedWindow = lib.filter
    (e:
      (e.pacing.enable or false)
      && e.maxWeeklyPercent == null
      && e.maxMonthlyPercent == null
    )
    (lib.flatten (lib.attrValues cfg.modelFallback.chains));

  # jq filter: input is the cache file { usage: {...} }; $chain is the ordered
  # chain array; $now is unix seconds from the selector's clock.
  #
  # The program lives in model-select.jq and is loaded at RUNTIME via
  # `jq -f <store-path>` (not interpolated into the generated shell script).
  # This is deliberate: interpolating the program text inside a single-quoted
  # bash argument silently broke the moment the program contained an
  # apostrophe ("entry's" — caught live 2026-08-26, self-improve-usage
  # Tier 1 Task 2), and the old inline form required a "no apostrophes by
  # construction" invariant nobody could enforce. A store path needs no
  # quoting, and the nixtest suite (tests/opencode-model-fallback_test.nix)
  # runs the exact same file.
  #
  # Pacing (D1–D4): ONLY for entries with pacing.enable = true on the
  # weekly/monthly windows; periodStart derives from resetsAt alone (weekly
  # −7d exact, monthly −30d APPROXIMATE — see README), paceCap =
  # min(100, elapsed% + buffer), inert while elapsed% < floor, and the entry
  # stays subject to its static caps as hard ceilings: eligible iff
  # percent <= min(static, pace). Entries without the flag are judged on
  # static caps alone. Rolling never consults pacing fields.
  resolveJqFile = ./model-select.jq;
in
{
  # ── Chains config → ~/.config/opencode/model-fallback.json ────────────────
  # NOTE: fallbackConfigFile already begins with ".config/", so no extra dot.
  home.file."${fallbackConfigFile}" = mkIf (cfg.modelFallback.chains != { }) {
    text = builtins.toJSON {
      chains =
        if pacingWithoutPacedWindow != [ ] then
          throw ''
            my.programs.opencode.modelFallback: pacing.enable is set on a chain
            entry that has neither maxWeeklyPercent nor maxMonthlyPercent.
            Pacing applies ONLY to the weekly/monthly windows (the rolling
            window is a trailing 5h sliding window with no fixed anchor and
            cannot be paced). Either set a weekly/monthly cap or drop pacing.enable.''
        else
          cfg.modelFallback.chains;
    };
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

      Exit codes: 0 resolved (model id on stdout); 3 missing config/cache;
      4 no chain configured for the agent; 5 chain exhausted with a blockedTerminal
      last entry — callers must treat this as "do not dispatch", not an error to retry.
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
            # The program is loaded with -f from its store path (see
            # resolveJqFile above for why it is not interpolated into this
            # script). NOW supplies the selector's own clock for pace caps.
            resolve_chain() {
              local now
              now=$(date +%s)
              jq -re -f ${resolveJqFile} --argjson chain "$1" --argjson now "$now" "$CACHE_FILE" 2>/dev/null || true
            }

            # Last entry of a chain is the always-eligible safety net by convention;
            # an exhausted chain degrades to it instead of failing hard. A chain
            # whose last entry is a blockedTerminal marker (no model) has NO safety
            # net by design: exhaustion must surface as BLOCKED (exit 5), never as
            # a degraded model choice.
            last_model_of_chain() {
              jq -rn '. | last | (.model // empty)' <<< "$1"
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
                if [ -z "$winner" ]; then
                  echo "opencode-model-select: chain for agent=''${agent:-default} exhausted; no free-tier terminal — BLOCKED" >&2
                  exit 5
                fi
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
            # NOTE: a BLOCKED/unresolvable agent is skipped and its PREVIOUS
            # modelsByAgent entry is left in place — the file cannot distinguish
            # fresh-resolved from carried-over entries. The stderr line below
            # makes that visible (self-improve-usage Tier 0 §2c secondary wrinkle).
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
    '')
  ];
}
