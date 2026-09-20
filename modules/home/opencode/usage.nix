# OpenCode Go subscription usage — CLI + cache refresher.
#
# Queries the (undocumented) OpenCode Go usage endpoint
#   GET https://opencode.ai/zen/go/v1/usage   (Bearer <API key>)
# which returns rolling / weekly / monthly window percentages and reset
# times. Provides:
#   - `opencode-go-usage`      CLI: human table (default) or `--json`
#   - a systemd user timer that refreshes ~/.cache/opencode/go-usage.json
#     every 5 minutes so the proxy dashboard can read the cached snapshot.
#   - the budget-pacing slice snapshot (~/.cache/opencode/go-usage-slices.json)
#     via snapshot-roll.sh, consumed by the model selector's "budget" pacing
#     mode (model-select.jq / README "Budget pacing").
{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.opencode;
  goCfg = cfg.opencode-go;

  usageJson = "%{XDG_CACHE_HOME:-$HOME/.cache}/opencode/go-usage.json";

  # Slice-snapshot roll logic, standalone so the nixtest suite can run the
  # exact bytes (tests/opencode-model-fallback_test.nix).
  sliceRoll = pkgs.writeShellScriptBin "opencode-go-slices-roll"
    (builtins.readFile ./snapshot-roll.sh);

  usageCli = pkgs.writeShellApplication {
    name = "opencode-go-usage";
    runtimeInputs = with pkgs; [ curl jq coreutils sliceRoll ];
    text = ''
      set -euo pipefail

      KEY_FILE=${lib.escapeShellArg goCfg.keyFile}
      CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/opencode"
      CACHE_FILE="''${CACHE_DIR}/go-usage.json"
      SLICE_FILE="''${CACHE_DIR}/go-usage-slices.json"
      SLICE_HOURS=24

      [ -r "$KEY_FILE" ] || { echo "opencode-go-usage: cannot read key file $KEY_FILE" >&2; exit 1; }
      KEY=$(tr -d '[:space:]' < "$KEY_FILE")

      JSON=$(curl -fsS --max-time 15 \
        -H "Authorization: Bearer $KEY" \
        https://opencode.ai/zen/go/v1/usage)

      # Validate shape before trusting it
      echo "$JSON" | jq -e '.usage.rolling.percent != null and .usage.weekly.percent != null and .usage.monthly.percent != null' >/dev/null

      if [ "''${1:-}" = "--json" ]; then
        echo "$JSON"
      elif [ "''${1:-}" = "--quiet" ]; then
        : # no output; used by the refresh timer
      else
        echo "$JSON" | jq -r '
          # DISPLAY-ONLY dollar estimate: percent * published limit
          # ($12/5h, $30/wk, $60/mo per https://opencode.ai/docs/go).
          # opencode may change these limits without API notice — this is a
          # display estimate ONLY; never feed it into selection logic (the
          # fallback selector consumes raw percents exclusively).
          def fmt($w; $limit):
            ($w.resetsAt | sub("\\.[0-9]+Z$"; "Z") | fromdate | strftime("%a %Y-%m-%d %H:%M UTC")) as $reset
            | (($w.percent / 100 * $limit * 100 | round) / 100) as $usd
            | "\($w.status)\t\($w.percent)%\t~$\($usd)\t\($reset)";
          "window\tstatus\tused\test.spend\tresets",
          ("rolling\t" + fmt(.usage.rolling; 12)),
          ("weekly \t" + fmt(.usage.weekly; 30)),
          ("monthly\t" + fmt(.usage.monthly; 60))
        ' | column -t -s $'\t'
      fi

      # Cache for the dashboard (atomic replace)
      mkdir -p "$CACHE_DIR"
      printf '%s' "$JSON" \
        | jq '. + {fetchedAt: (now | todate)}' \
        > "''${CACHE_FILE}.tmp"
      mv "''${CACHE_FILE}.tmp" "$CACHE_FILE"

      # Budget-pacing slice snapshot (best-effort, after the cache write so a
      # failure here never loses the usage cache). See snapshot-roll.sh.
      opencode-go-slices-roll "$JSON" "$SLICE_FILE" "$SLICE_HOURS" || \
        { echo "opencode-go-usage: slice snapshot roll failed (ignored)" >&2; }
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = lib.mkIf goCfg.usage.enable [ usageCli ];

    systemd.user.services.opencode-go-usage = lib.mkIf goCfg.usage.enable {
      Unit = {
        Description = "Refresh cached OpenCode Go usage snapshot";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe usageCli} --quiet";
        # Usage polling is best-effort; never spam the journal on flake.
        SuccessExitStatus = [ "0" ];
      };
    };

    systemd.user.timers.opencode-go-usage = lib.mkIf goCfg.usage.enable {
      Unit = {
        Description = "Periodic OpenCode Go usage refresh";
      };
      Timer = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
      };
      Install = {
        WantedBy = [ "timers.target" ];
      };
    };
  };
}
