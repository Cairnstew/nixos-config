{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.tailscaleWatchdog;

  watchdogPkg = pkgs.writeShellApplication {
    name = "tailscale-watchdog";
    runtimeInputs = [ pkgs.tailscale pkgs.msmtp pkgs.jq pkgs.iproute2 pkgs.coreutils ];
    text = ''
      LAST_ALERT_FILE="${cfg.stateDir}/last-alert-epoch"
      LAST_STATE_FILE="${cfg.stateDir}/last-known-state"
      SECRET="/run/agenix/mcp-better-email-password"

      # Check secret exists
      if [[ ! -f "$SECRET" ]]; then
        echo "tailscale-watchdog: SMTP secret not found at $SECRET, skipping email" >&2
        exit 0
      fi

      # Get Tailscale state
      TS_STATE=$(tailscale status --json 2>/dev/null \
    | jq -r '.BackendState // "unknown"' 2>/dev/null \
    || echo "unreachable")
      LAST_STATE=$(cat "$LAST_STATE_FILE" 2>/dev/null || echo "unknown")

      # Always update last-known-state
      echo "$TS_STATE" > "$LAST_STATE_FILE"

      # If running — check for recovery (was down, now up)
      if [[ "$TS_STATE" == "Running" ]]; then
        if [[ "$LAST_STATE" != "Running" && "$LAST_STATE" != "unknown" ]]; then
          BODY="Tailscale RECOVERED on $(hostname) at $(date -u).
      Previous state: $LAST_STATE
      Current state: Running"
          APP_PASSWORD=$(cat "$SECRET")
          echo "$BODY" | msmtp \
            --host=smtp.gmail.com \
            --port=587 \
            --auth=on \
            --tls=on \
            --tls-starttls=on \
            --from="${cfg.emailTo}" \
            --user="${cfg.emailTo}" \
            --password="$APP_PASSWORD" \
            "${cfg.emailTo}"
        fi
        exit 0
      fi

      # Tailscale is NOT running — check cooldown
      NOW=$(date +%s)
      LAST_ALERT=$(cat "$LAST_ALERT_FILE" 2>/dev/null || echo "0")
      ELAPSED=$(( NOW - LAST_ALERT ))

      if (( ELAPSED < ${toString cfg.alertCooldown} )); then
        exit 0
      fi

      # Send alert
      LAN_IPS=$(ip -4 addr show | awk '/inet / && !/127\./ {print $2}' | cut -d/ -f1)
      HOSTNAME=$(hostname)
      SSH_LINES=""
      while IFS= read -r ip; do
        [[ -n "$ip" ]] && SSH_LINES="$SSH_LINES  ssh seanc@$ip
"
      done <<< "$LAN_IPS"
      BODY="Tailscale is DOWN on $HOSTNAME.
State: $TS_STATE
Time: $(date -u)
LAN IPs for direct SSH:
$SSH_LINES"

      APP_PASSWORD=$(cat "$SECRET")
      echo "$BODY" | msmtp \
        --host=smtp.gmail.com \
        --port=587 \
        --auth=on \
        --tls=on \
        --tls-starttls=on \
        --from="${cfg.emailTo}" \
        --user="${cfg.emailTo}" \
        --password="$APP_PASSWORD" \
        "${cfg.emailTo}"

      echo "$NOW" > "$LAST_ALERT_FILE"
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.tailscale-watchdog = {
      description = "Tailscale connectivity watchdog with email alerts";
      after = [ "tailscaled.service" "network-online.target" ];
      wants = [ "tailscaled.service" "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "tailscale-watchdog";
        ExecStart = "${watchdogPkg}/bin/tailscale-watchdog";
      };
    };

    systemd.timers.tailscale-watchdog = {
      description = "Periodic tailscale connectivity check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.startDelay;
        OnUnitActiveSec = cfg.interval;
        Persistent = true;
      };
    };
  };
}
