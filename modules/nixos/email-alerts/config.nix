{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.emailAlerts;
  secretPath = "/run/agenix/${cfg.secretName}";

  sendAlert = pkgs.writeShellApplication {
    name = "send-alert";
    runtimeInputs = with pkgs; [ msmtp coreutils gnugrep ];
    text = ''
            set -euo pipefail

            SUBJECT=""
            BODY=""
            TO=""

            while [[ $# -gt 0 ]]; do
              case "$1" in
                -s|--subject) SUBJECT="$2"; shift 2 ;;
                -b|--body)    BODY="$2"; shift 2 ;;
                -t|--to)      TO="$2"; shift 2 ;;
                *)            echo "Usage: send-alert -s SUBJECT -b BODY [-t TO]" >&2; exit 1 ;;
              esac
            done

            if [[ -z "$SUBJECT" || -z "$BODY" ]]; then
              echo "send-alert: subject and body are required" >&2
              exit 1
            fi

            # Use default recipient(s) if none specified
            if [[ -z "$TO" ]]; then
              TO="${lib.concatStringsSep " " cfg.to}"
            fi

            # Check secret exists
            SECRET="${secretPath}"
            if [[ ! -f "$SECRET" ]]; then
              echo "send-alert: SMTP secret not found at $SECRET, skipping" | \
                systemd-cat -t send-alert -p warning
              exit 0
            fi

            FULL_BODY="$BODY

      ---
      Sent from $(hostname) at $(date -u)"
            # shellcheck disable=SC2086
            echo "$FULL_BODY" | msmtp \
              --host="${cfg.smtp.host}" \
              --port="${toString cfg.smtp.port}" \
              --auth=on \
              --tls=on \
              --tls-starttls=on \
              --from="${cfg.smtp.from}" \
              --user="${cfg.smtp.user}" \
              --passwordeval="cat '$SECRET' | tr -d '[:space:]'" \
              $TO

            echo "send-alert: alert sent to $TO" | \
              systemd-cat -t send-alert -p notice
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ sendAlert ];
  };
}
