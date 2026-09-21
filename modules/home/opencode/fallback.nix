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
  # Pacing/Degrade (D1–D4): ONLY for entries with pacing.enable = true on the
  # weekly/monthly windows; periodStart derives from resetsAt alone (weekly
  # −7d exact, monthly −30d exact — a fixed 30-day window anchored at
  # 2026-09-20T09:25:34Z, see README). Two modes:
  #   "elapsed" — paceCap = min(100, elapsed% + buffer), inert below floor.
  #   "budget"  — sliceCap = usageAtStart + (100 − usageAtStart)/slicesLeft
  #               from the slice snapshot (go-usage-slices.json, written by
  #               usage.nix), monthly only by default.
  # The entry stays subject to its static caps as hard ceilings: eligible
  # iff percent <= min(static, pace). Entries without the flag are judged on
  # static caps alone. Rolling never consults pacing fields.
  #
  # Degrade rule (2026-09-20): a chain's LAST entry is the safety net ONLY
  # when it is cap-free (model set, no static caps). On unusable usage data
  # (any window missing / percent not a number) — and on exhaustion — a chain
  # with a cap-free tail degrades to it (exit 0, one stderr warning); a chain
  # ending in blockedTerminal or a CAPPED entry exits 5 (BLOCKED) instead of
  # running a paid model with no enforcement.
  resolveJqFile = ./model-select.jq;

  # The selector logic is a standalone script (env-parameterized via
  # OPENCODE_SELECT_* so the nixtest suite runs the exact deployed bytes);
  # this wrapper binds the baked store paths and paths.
  modelSelectScript = pkgs.writeShellScript "opencode-model-select-core"
    (builtins.readFile ./model-select.sh);
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
      export OPENCODE_SELECT_JQ="${resolveJqFile}"
      export OPENCODE_SELECT_CONFIG="''${XDG_CONFIG_HOME:-$HOME/.config}/opencode/model-fallback.json"
      export OPENCODE_SELECT_CACHE="${cfg.modelFallback.cacheFile}"
      export OPENCODE_SELECT_SLICE="${cfg.modelFallback.sliceFile}"
      export OPENCODE_SELECT_LOG="${cfg.modelFallback.logFile}"
      export OPENCODE_SELECT_ENSEMBLE="${cfg.modelFallback.repoDir}/.opencode/ensemble.json"
      exec ${modelSelectScript} "$@"
    '')
  ];
}
