{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.tailscaleWatchdog;

  watchdogPkg = pkgs.writeShellApplication {
    name = "tailscale-watchdog";
    runtimeInputs = [ pkgs.tailscale pkgs.jq pkgs.iproute2 pkgs.coreutils pkgs.systemd ];
    text = ''
      FALLBACK_FILE="${cfg.stateDir}/zerotier-fallback-active"
      LAST_ALERT_FILE="${cfg.stateDir}/last-alert-epoch"
      LAST_STATE_FILE="${cfg.stateDir}/last-known-state"
      SEND_ALERT="send-alert"

      # ── Zerotier fallback management ──────────────────────────────────────
      manage_zerotier() {
        if ! systemctl cat zerotierone >/dev/null 2>&1; then
          return  # zerotier not installed
        fi
        local ZT_STATE
        ZT_STATE=$(systemctl is-active zerotierone 2>/dev/null || echo "inactive")
        if [[ "$1" == "start" && "$ZT_STATE" == "inactive" ]]; then
          systemctl start zerotierone
          touch "$FALLBACK_FILE"
          echo "Zerotier started as fallback (tailscale down)"
        elif [[ "$1" == "stop" && -f "$FALLBACK_FILE" ]]; then
          systemctl stop zerotierone
          rm -f "$FALLBACK_FILE"
          echo "Zerotier stopped (tailscale recovered)"
        fi
      }

      # Get Tailscale state
      TS_STATE=$(tailscale status --json 2>/dev/null \
    | jq -r '.BackendState // "unknown"' 2>/dev/null \
    || echo "unreachable")
      LAST_STATE=$(cat "$LAST_STATE_FILE" 2>/dev/null || echo "unknown")

      # Always update last-known-state
      echo "$TS_STATE" > "$LAST_STATE_FILE"

      # If running — handle recovery and stop zerotier fallback
      if [[ "$TS_STATE" == "Running" ]]; then
        manage_zerotier stop
        if [[ "$LAST_STATE" != "Running" && "$LAST_STATE" != "unknown" ]]; then
          BODY="Tailscale RECOVERED on $(hostname) at $(date -u).
Previous state: $LAST_STATE
Current state: Running"
          $SEND_ALERT -s "Tailscale Recovered on $(hostname)" -b "$BODY" \
            ${lib.optionalString (cfg.emailTo != null) "-t ${cfg.emailTo}"} || true
        fi
        exit 0
      fi

      # Tailscale is NOT running — start zerotier fallback
      manage_zerotier start

      # Check cooldown before sending alert email
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

      $SEND_ALERT -s "Tailscale Down on $(hostname)" -b "$BODY" \
        ${lib.optionalString (cfg.emailTo != null) "-t ${cfg.emailTo}"} || true

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
