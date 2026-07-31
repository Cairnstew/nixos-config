{ config, lib, pkgs, flake, ... }:
let
  inherit (flake.config.me) username;
  cfg = config.my.services.tailscaleWatchdog;
  tailscaleMtu = config.my.services.tailscale.mtu;

  watchdogPkg = pkgs.writeShellApplication {
    name = "tailscale-watchdog";
    runtimeInputs = [
      pkgs.tailscale
      pkgs.jq
      pkgs.iproute2
      pkgs.iputils
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      LAST_ALERT_FILE="${cfg.stateDir}/last-alert-epoch"
      LAST_STATE_FILE="${cfg.stateDir}/last-known-state"
      SEND_ALERT="send-alert"
      EXPECTED_MTU="${lib.optionalString (tailscaleMtu != null) (toString tailscaleMtu)}"
      HOSTNAME=$(hostname)

      sendAlert() {
        local subject="$1" body="$2"
        $SEND_ALERT -s "$subject" -b "$body" \
          ${lib.optionalString (cfg.emailTo != null) "-t ${cfg.emailTo}"} || true
        echo "$(date +%s)" > "$LAST_ALERT_FILE"
      }

      inCooldown() {
        local now last elapsed
        now=$(date +%s)
        last=$(cat "$LAST_ALERT_FILE" 2>/dev/null || echo "0")
        elapsed=$((now - last))
        [[ $elapsed -lt ${toString cfg.alertCooldown} ]]
      }

      # BackendState is a userspace signal only — a wedged kernel data plane
      # still reports "Running". Always store it for recovery detection.
      TS_STATE=$(tailscale status --json 2>/dev/null \
        | jq -r '.BackendState // "unknown"' 2>/dev/null \
        || echo "unreachable")
      LAST_STATE=$(cat "$LAST_STATE_FILE" 2>/dev/null || echo "unknown")
      echo "$TS_STATE" > "$LAST_STATE_FILE"

      # ── Tailscale not running — alert only (zerotier is always-on) ────────
      if [[ "$TS_STATE" != "Running" ]]; then
        if inCooldown; then exit 0; fi

        LAN_IPS=$(ip -4 addr show | awk '/inet / && !/127\./ {print $2}' | cut -d/ -f1)
        SSH_LINES=""
        while IFS= read -r ip; do
          [[ -n "$ip" ]] && SSH_LINES="$SSH_LINES  ssh ${username}@$ip
      "
        done <<< "$LAN_IPS"
        BODY="Tailscale is DOWN on $HOSTNAME.
      State: $TS_STATE
      Time: $(date -u)
      LAN IPs for direct SSH:
      $SSH_LINES"

        sendAlert "Tailscale Down on $HOSTNAME" "$BODY"
        exit 0
      fi

      # ── Running but data plane unhealthy — auto-repair + alert ─────────────
      FAIL_REASON=""
      if ! ip link show dev tailscale0 >/dev/null 2>&1; then
        FAIL_REASON="tailscale0 interface is missing"
      elif ! ip link show dev tailscale0 | grep -q "state UP"; then
        FAIL_REASON="tailscale0 interface is not UP"
      elif [[ -n "$EXPECTED_MTU" ]] && [[ "$(cat /sys/class/net/tailscale0/mtu 2>/dev/null)" != "$EXPECTED_MTU" ]]; then
        FAIL_REASON="tailscale0 MTU drifted to $(cat /sys/class/net/tailscale0/mtu 2>/dev/null) (expected $EXPECTED_MTU)"
      else
        SELF_IP=$(tailscale ip -4 2>/dev/null | head -1 || true)
        if [[ -n "$SELF_IP" ]] && ! ping -c 1 -W 2 "$SELF_IP" >/dev/null 2>&1; then
          FAIL_REASON="kernel data path dead (self-ping $SELF_IP failed)"
        fi
      fi

      if [[ -n "$FAIL_REASON" ]]; then
        if inCooldown; then exit 0; fi
        ${lib.optionalString cfg.autoRepair ''
          systemctl restart tailscaled || true
        ''}
        BODY="Tailscale data plane DEGRADED on $HOSTNAME.
      BackendState: Running (tailscaled healthy)
      Issue: $FAIL_REASON
      Time: $(date -u)
      ${lib.optionalString cfg.autoRepair "Action: tailscaled restarted to recover"}"

        sendAlert "Tailscale Data Plane Degraded on $HOSTNAME" "$BODY"
        exit 0
      fi

      # ── Healthy — send recovery alert if it was previously down ────────────
      if [[ "$LAST_STATE" != "Running" && "$LAST_STATE" != "unknown" ]]; then
        BODY="Tailscale RECOVERED on $HOSTNAME at $(date -u).
      Previous state: $LAST_STATE
      Current state: Running"
        sendAlert "Tailscale Recovered on $HOSTNAME" "$BODY"
      fi
      exit 0
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
