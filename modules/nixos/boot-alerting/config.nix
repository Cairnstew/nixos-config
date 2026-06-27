{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.bootAlerting;

  emergencyScript = pkgs.writeShellScript "emergency-email" ''
    set +e
    SECRET="/run/agenix/mcp-better-email-password"
    FLAG="${cfg.stateDir}/emergency-flag"
    mkdir -p "${cfg.stateDir}"

    # Best-effort: try to bring up network
    ${pkgs.systemd}/bin/systemctl start systemd-networkd --no-block 2>/dev/null
    sleep ${toString cfg.emergencyHook.networkTimeout}

    # Check secret exists
    if [[ ! -f "$SECRET" ]]; then
      echo "emergency-email: SMTP secret not found, skipping" | \
        ${pkgs.systemd}/bin/systemd-cat -t emergency-email -p warning
      exit 0
    fi

    # Get LAN IPs
    LAN_IPS=$(${pkgs.iproute2}/bin/ip -4 addr show \
      | ${pkgs.gawk}/bin/awk '/inet / && !/127\./ {print $2}' \
      | ${pkgs.coreutils}/bin/cut -d/ -f1)
    HOSTNAME=$(${pkgs.coreutils}/bin/hostname)

    # Build SSH lines
    SSH_LINES=""
    while IFS= read -r ip; do
      [[ -n "$ip" ]] && SSH_LINES="$SSH_LINES  ssh seanc@$ip
"
    done <<< "$LAN_IPS"

    NOW=$(${pkgs.coreutils}/bin/date -u +%s)
    BODY="EMERGENCY MODE on $HOSTNAME
Time: $(${pkgs.coreutils}/bin/date -u)
Boot entered emergency.target -- system may be unbootable.

LAN IPs for direct SSH:
$SSH_LINES

Check journal:
  journalctl -b -1 -p 3
  journalctl -b -1 -u emergency.target"

    APP_PASSWORD=$(${pkgs.coreutils}/bin/cat "$SECRET")
    echo "$BODY" | ${pkgs.msmtp}/bin/msmtp \
      --host=smtp.gmail.com \
      --port=587 \
      --auth=on \
      --tls=on \
      --tls-starttls=on \
      --from="${cfg.emailTo}" \
      --user="${cfg.emailTo}" \
      --password="$APP_PASSWORD" \
      "${cfg.emailTo}"

    echo "$NOW" > "$FLAG"
  '';

  detectorPkg = pkgs.writeShellApplication {
    name = "boot-failure-detector";
    runtimeInputs = with pkgs; [ msmtp systemd coreutils iproute2 gawk gnugrep ];
    text = ''
      set -euo pipefail
      FLAG="${cfg.stateDir}/emergency-flag"
      SECRET="/run/agenix/mcp-better-email-password"

      # If no emergency flag, previous boot was clean
      if [[ ! -f "$FLAG" ]]; then
        exit 0
      fi

      # If secret missing, log and exit
      if [[ ! -f "$SECRET" ]]; then
        echo "SMTP secret not found, skipping alert" | \
          systemd-cat -t boot-failure-detector -p warning
        exit 0
      fi

      EMERGENCY_TIME=$(cat "$FLAG")

      JOURNAL_EXCERPT=$(journalctl -b -1 -p 3 --no-pager -n 50 2>/dev/null || echo "No journal entries found")
      LAN_IPS=$(ip -4 addr show | awk '/inet / && !/127\./ {print $2}' | cut -d/ -f1)
      HOSTNAME=$(hostname)

      SSH_LINES=""
      while IFS= read -r ip; do
        [[ -n "$ip" ]] && SSH_LINES="$SSH_LINES  ssh seanc@$ip
"
      done <<< "$LAN_IPS"

      BODY="BOOT FAILURE DETECTED on $HOSTNAME

Previous boot entered emergency.target at timestamp: $EMERGENCY_TIME
This alert confirms the system has rebooted and is now operational.

The previous generation may be broken. Review the boot journal before rebooting again.

LAN IPs for direct SSH:
$SSH_LINES

Journal errors from failed boot (last 50 lines):
$JOURNAL_EXCERPT"

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

      # Consume the flag
      rm -f "$FLAG"
      echo "Previous-boot failure alert sent, flag consumed" | \
        systemd-cat -t boot-failure-detector -p notice
    '';
  };
in
{
  config = lib.mkIf cfg.enable {

    # ── Unit 1: Emergency hook for the current boot ────────────────────
    # Add ExecStartPost via attribute-level mkIf so it merges cleanly with
    # the existing systemd emergency.service definition rather than replacing it.
    systemd.services.emergency.serviceConfig.ExecStartPost =
      lib.mkIf cfg.emergencyHook.enable [ "${emergencyScript}" ];

    # ── Unit 2: Previous-boot detector (runs on next clean boot) ──────
    systemd.services.boot-failure-detector = lib.mkIf cfg.detectPreviousBoot {
      description = "Detect previous boot emergency and send detailed alert";
      after = [ "network-online.target" "multi-user.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "boot-alerting";
        ExecStart = "${detectorPkg}/bin/boot-failure-detector";
      };
    };
  };
}
