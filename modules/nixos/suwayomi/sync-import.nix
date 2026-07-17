{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf;
  cfg = config.my.services.suwayomi;
  exportCfg = cfg.sync.export;
  importCfg = cfg.sync.import;
in
{
  config = mkIf (cfg.enable && importCfg.enable) {
    systemd.services.suwayomi-sync-import = {
      description = "Suwayomi backup import from git repo";
      after = [ "network-online.target" "suwayomi-server.service" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "suwayomi-server.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellApplication {
          name = "suwayomi-sync-import";
          runtimeInputs = with pkgs; [ curl jq git coreutils tailscale ];
          text = ''
            set -euo pipefail

            REPO="${exportCfg.repoPath}"
            DEST="${exportCfg.destFile}"
            PORT="${toString cfg.settings.server.port}"
            STATE_DIR="${cfg.dataDir}/sync-import"
            LAST_HASH_FILE="$STATE_DIR/last-imported-hash"
            BACKUP_FILE="$REPO/$DEST"

            # Resolve local Suwayomi bind address
            BIND_IP="127.0.0.1"
            ${lib.optionalString cfg.autoBindTailscaleIp ''
              TS_IP=$(tailscale ip -4 2>/dev/null) && BIND_IP="$TS_IP"
            ''}
            BASE="http://$BIND_IP:$PORT"

            # 1. Pull latest from git (same auth pattern as export)
            if [ -f "${exportCfg.secretPath}" ] && [ -x "${pkgs.git}/bin/git" ]; then
              GIT_TOKEN=$(cat "${exportCfg.secretPath}")
              git -c safe.directory="$REPO" -C "$REPO" pull "https://oauth2:''${GIT_TOKEN}@github.com/Cairnstew/nixos-config.git" master --ff-only 2>&1 | \
                ${pkgs.systemd}/bin/systemd-cat -t suwayomi-sync-import -p info || true
            else
              git -c safe.directory="$REPO" -C "$REPO" pull --ff-only 2>&1 | \
                ${pkgs.systemd}/bin/systemd-cat -t suwayomi-sync-import -p info || true
            fi
            # 2. Check if backup file exists
            if [ ! -f "$BACKUP_FILE" ]; then
              echo "suwayomi-sync-import: no backup file at $BACKUP_FILE — skipping"
              exit 0
            fi

            # 3. Compare hash with last imported
            mkdir -p "$STATE_DIR"
            NEW_HASH=$(${pkgs.coreutils}/bin/sha256sum "$BACKUP_FILE" | cut -d' ' -f1)
            if [ -f "$LAST_HASH_FILE" ]; then
              LAST_HASH=$(cat "$LAST_HASH_FILE" 2>/dev/null || echo "")
              if [ "$NEW_HASH" = "$LAST_HASH" ]; then
                echo "suwayomi-sync-import: backup unchanged — skipping import"
                # Still refresh extension list from repos
                curl -s -X POST "$BASE/api/graphql" \
                  -H "Content-Type: application/json" \
                  -d '{"query":"mutation { fetchExtensions(input: {}) { clientMutationId } }"}' > /dev/null 2>&1 || true
                exit 0
              fi
            fi

            # 4. Restore backup via multipart upload (no validateBackup mutation available)
            echo "suwayomi-sync-import: restoring backup..."
            RESTORE=""
            for i in $(${pkgs.coreutils}/bin/seq 1 10); do
              RESTORE=$(curl -s -X POST "$BASE/api/graphql" \
                -F "operations={\"query\":\"mutation(\$file: Upload!) { restoreBackup(input: { backup: \$file, flags: { includeManga: true, includeCategories: true, includeChapters: false, includeTracking: true, includeHistory: true, includeClientData: false, includeServerSettings: false } }) { status { state } } }\",\"variables\":{\"file\":null}}" \
                -F "map={\"0\":[\"variables.file\"]}" \
                -F "0=@$BACKUP_FILE;type=application/octet-stream" 2>&1) || true
              if [ -n "$RESTORE" ]; then
                STATE=$(echo "$RESTORE" | ${pkgs.jq}/bin/jq -r '.data.restoreBackup.status.state // "unknown"' 2>/dev/null || echo "")
                if [ "$STATE" != "unknown" ] && [ -n "$STATE" ]; then
                  break
                fi
              fi
              echo "suwayomi-sync-import: server not ready, retry $i/10..."
              sleep 3
            done
            STATE=$(echo "$RESTORE" | ${pkgs.jq}/bin/jq -r '.data.restoreBackup.status.state // "unknown"' 2>/dev/null || echo "no-connection")
            echo "suwayomi-sync-import: restore state: $STATE"

            # 5. Refresh extension list from configured repos
            echo "suwayomi-sync-import: fetching extensions..."
            curl -s -X POST "$BASE/api/graphql" \
              -H "Content-Type: application/json" \
              -d '{"query":"mutation { fetchExtensions(input: {}) { clientMutationId } }"}' > /dev/null 2>&1 || true

            # 6. Track hash to avoid re-importing
            echo "$NEW_HASH" > "$LAST_HASH_FILE"
          '';
        }}/bin/suwayomi-sync-import";
        NoNewPrivileges = true;
        ProtectHome = false;
      };
    };

    systemd.timers.suwayomi-sync-import = {
      description = "Timer for Suwayomi backup import";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = importCfg.interval;
        Persistent = true;
      };
    };
  };
}
