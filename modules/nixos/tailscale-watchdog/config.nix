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
      CANARY_PEERS="${lib.concatStringsSep " " cfg.canaryPeers}"
      HOSTNAME=$(uname -n)

      # send-alert is installed via environment.systemPackages (email-alerts module),
      # which is not on the minimal systemd service PATH.
      export PATH="/run/current-system/sw/bin:$PATH"

      sendAlert() {
        local subject="$1" body="$2"
        $SEND_ALERT -s "$subject" -b "$body" \
          ${lib.optionalString (cfg.emailTo != null) "-t ${cfg.emailTo}"} || true
        date +%s > "$LAST_ALERT_FILE"
      }

      inCooldown() {
        local now last elapsed
        now=$(date +%s)
        last=$(cat "$LAST_ALERT_FILE" 2>/dev/null || echo "0")
        elapsed=$((now - last))
        [[ $elapsed -lt ${toString cfg.alertCooldown} ]]
      }

      # Kernel data-plane probe to a real peer. The local checks above (interface
      # UP, MTU match, self-ping) only prove the LOCAL tunnel is configured; a
      # tailscaled data-plane wedge accepts control-plane ping/handshakes yet
      # drops forwarded IP packets, so it passes every local check while all TCP
      # to a peer times out. To catch it we ping a peer THROUGH tailscale0: if an
      # Online peer exists but none answer, the tunnel is not forwarding packets.
      # Empty success, non-empty failure message.
      checkRemotePeer() {
        local peer="" candidates="$CANARY_PEERS"
        if [[ -z "$candidates" ]]; then
          candidates=$(tailscale status --json 2>/dev/null | jq -r '
            [.Peer | to_entries[]
             | select(.value.Online == true)
             | select((.value.OS // "") != "iOS" and (.value.OS // "") != "windows")
             | {ip: .value.TailscaleIPs[0], seen: (.value.LastSeen // "0000-00-00T00:00:00Z")}]
            | sort_by(.seen) | reverse | .[].ip' 2>/dev/null)
        fi
        # No online peer to test (empty tailnet / not authenticated) — nothing
        # the data plane can be checked against, so don't flag.
        if [[ -z "$candidates" ]]; then
          return 0
        fi
        # If no peer answers on the first pass, retry once after a short pause
        # so a transient loss or a just-restarted peer doesn't false-positive.
        for pass in 1 2; do
          for peer in $candidates; do
            if ping -c 2 -W 2 "$peer" >/dev/null 2>&1; then
              return 0
            fi
          done
          [[ $pass -eq 1 ]] || break
          sleep 5
        done
        echo "no data path to online peer(s): $candidates"
        return 1
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
      elif [[ $(($(cat /sys/class/net/tailscale0/flags 2>/dev/null || echo 0) & 1)) -ne 1 ]]; then
        FAIL_REASON="tailscale0 interface is not UP (IFF_UP unset)"
      elif [[ -n "$EXPECTED_MTU" ]] && [[ "$(cat /sys/class/net/tailscale0/mtu 2>/dev/null)" != "$EXPECTED_MTU" ]]; then
        FAIL_REASON="tailscale0 MTU drifted to $(cat /sys/class/net/tailscale0/mtu 2>/dev/null) (expected $EXPECTED_MTU)"
      else
        SELF_IP=$(tailscale ip -4 2>/dev/null | head -1 || true)
        if [[ -n "$SELF_IP" ]] && ! ping -c 1 -W 2 "$SELF_IP" >/dev/null 2>&1; then
          FAIL_REASON="kernel data path dead (self-ping $SELF_IP failed)"
        else
          REMOTE_FAIL=$(checkRemotePeer || true)
          if [[ -n "$REMOTE_FAIL" ]]; then
            FAIL_REASON="remote data plane dead ($REMOTE_FAIL)"
          fi
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
