{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.suwayomi.sync.export;

  exportPkg = pkgs.writeShellApplication {
    name = "suwayomi-sync-export";
    runtimeInputs = with pkgs; [ curl jq git coreutils gnused diffutils ];
    text = ''
      set -euo pipefail

      REPO="${cfg.repoPath}"
      DEST="${cfg.destFile}"
      PORT="${toString config.my.services.suwayomi.settings.server.port}"

      # 1. Fire mutation to create filtered backup
      # shellcheck disable=SC2016
      RESPONSE=$(curl -s -X POST "http://127.0.0.1:$PORT/api/graphql" \
        -H "Content-Type: application/json" \
        -d '{"query":"mutation($input: CreateBackupInput!) { createBackup(input: $input) { url } }","variables":{"input":{"flags":{"includeManga":true,"includeCategories":true,"includeChapters":false,"includeTracking":false,"includeHistory":false,"includeClientData":false,"includeServerSettings":false}}}}')

      URL=$(echo "$RESPONSE" | ${pkgs.jq}/bin/jq -r '.data.createBackup.url')
      if [ -z "$URL" ] || [ "$URL" = "null" ]; then
        echo "suwayomi-sync: mutation failed — response: $RESPONSE" >&2
        exit 1
      fi

      # 2. Download the backup file
      TMPFILE=$(mktemp)
      curl -s -o "$TMPFILE" "http://127.0.0.1:$PORT$URL"

      # 3. Compare with existing file
      if [ -f "$REPO/$DEST" ] && cmp -s "$TMPFILE" "$REPO/$DEST"; then
        echo "suwayomi-sync: backup unchanged — skipping commit"
        rm -f "$TMPFILE"
        exit 0
      fi

      # 4. Install into repo
      mkdir -p "$(dirname "$REPO/$DEST")"
      mv "$TMPFILE" "$REPO/$DEST"
      chmod 644 "$REPO/$DEST"

      # 5. Git commit
      git -c safe.directory="$REPO" -C "$REPO" add "$DEST"
      git -c safe.directory="$REPO" \
        -c user.name="Suwayomi Sync" \
        -c user.email="suwayomi-sync@nixos" \
        -C "$REPO" commit \
        -m "suwayomi-sync: export $(date -Iseconds)" \
        --allow-empty-message 2>/dev/null || true

      # 6. Git push (optional) — GIT_ASKPASS helper reads token from agenix file
      # Git calls the helper separately for each prompt:
      #   call 1: $1 = "Username for 'https://github.com': "  → stdout: "oauth2"
      #   call 2: $1 = "Password for 'https://github.com': "  → stdout: "<token>"
      # The temp helper script stores only the path to the secret, never the value.
      ${lib.optionalString cfg.autoPush ''
          if [ -f "${cfg.secretPath}" ]; then
          export GIT_ASKPASS
          GIT_ASKPASS=$(mktemp)
          # quoted heredoc ('HELPER') prevents bash from expanding $1 at write time
          cat > "$GIT_ASKPASS" << 'HELPER'
          #!/bin/sh
          case "$1" in
          *Username*) echo "oauth2" ;;
          *Password*) exec cat "${cfg.secretPath}" ;;
          esac
          HELPER
          chmod +x "$GIT_ASKPASS"
          git -c safe.directory="$REPO" -C "$REPO" push 2>&1 | \
            ${pkgs.systemd}/bin/systemd-cat -t suwayomi-sync-export -p info || \
            echo "suwayomi-sync: push failed (non-fatal)" >&2
          rm -f "$GIT_ASKPASS"
          else
            echo "suwayomi-sync: secretPath not found at ${cfg.secretPath}, cannot push" >&2
            exit 1
          fi
      ''}
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.suwayomi-sync-export = {
      description = "Suwayomi filtered backup export to git repo";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${exportPkg}/bin/suwayomi-sync-export";
        NoNewPrivileges = true;
        ProtectHome = false;
      };
    };

    systemd.timers.suwayomi-sync-export = {
      description = "Timer for Suwayomi backup export";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.interval;
        Persistent = true;
      };
    };
  };
}
