{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.prowlarr;

  mkIndexerScript = idx:
    let
      fieldDefs = builtins.toJSON (map (f: {
        name = f.name;
        value = if f ? value && f.value != null then builtins.toString f.value else null;
        secretFile = if f ? credentialFile && f.credentialFile != null then builtins.toString f.credentialFile else null;
      }) idx.settings);
    in
    ''
      ID=$(echo "$EXISTING" | jq -r '.[] | select(.name == "${idx.name}") | .id // empty' | head -1)
      if [ -n "$ID" ]; then
        echo "prowlarr-setup: indexer '${idx.name}' already exists (id=$ID) — skipping"
      else
        echo "prowlarr-setup: creating indexer '${idx.name}'..."

        FIELDS='${fieldDefs}'
        FIELDS_BUILT="[]"
        for row in $(echo "$FIELDS" | jq -c '.[]'); do
          NAME=$(echo "$row" | jq -r '.name')
          SECRET_FILE=$(echo "$row" | jq -r '.secretFile // ""')
          if [ -n "$SECRET_FILE" ] && [ "$SECRET_FILE" != "null" ]; then
            VALUE=$(cat "$SECRET_FILE")
          else
            VALUE=$(echo "$row" | jq -r '.value // ""')
          fi
          FIELDS_BUILT=$(echo "$FIELDS_BUILT" | jq -c --arg name "$NAME" --arg value "$VALUE" '. + [{$name, $value}]')
        done

        PAYLOAD=$(jq -n -c \
          --arg name "${idx.name}" \
          --arg impl "${idx.implementation}" \
          --argjson priority ${toString idx.priority} \
          --argjson appProfileId ${toString idx.appProfileId} \
          --argjson enable ${if idx.enable then "true" else "false"} \
          --argjson fields "$FIELDS_BUILT" \
          '{
            enable: $enable,
            redirect: false,
            appProfileId: $appProfileId,
            priority: $priority,
            downloadClientId: 0,
            name: $name,
            implementationName: $impl,
            implementation: $impl,
            configContract: "\($impl)Settings",
            fields: $fields,
            tags: []
          }')

        RESPONSE=$(curl -sf -X POST "$BASE/api/v1/indexer" \
          -H "X-Api-Key: $API_KEY" \
          -H "Content-Type: application/json" \
          -d "$PAYLOAD" 2>&1) && \
        echo "prowlarr-setup: created '${idx.name}' successfully" || \
        echo "prowlarr-setup: failed to create '${idx.name}': $RESPONSE"
      fi
    '';

  setupPkg = pkgs.writeShellApplication {
    name = "prowlarr-setup-indexers";
    runtimeInputs = with pkgs; [ curl jq coreutils gnused ];
    text = ''
      set -euo pipefail

      DATA_DIR="${cfg.dataDir}"
      PORT="${toString cfg.port}"
      BASE="http://127.0.0.1:$PORT"

      API_KEY=$(grep -oP '<ApiKey>\K[^<]+' "$DATA_DIR/config.xml" 2>/dev/null || true)
      if [ -z "$API_KEY" ]; then
        echo "prowlarr-setup: no ApiKey found in config.xml — Prowlarr may not have started yet"
        exit 1
      fi

      EXISTING=$(curl -sf "$BASE/api/v1/indexer" -H "X-Api-Key: $API_KEY" 2>/dev/null || echo "[]")

      ${lib.concatStringsSep "\n" (map mkIndexerScript cfg.indexers)}
    '';
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.indexers != [ ]) {
    systemd.services.prowlarr-setup-indexers = {
      description = "Declarative Prowlarr indexer setup";
      after = [ "prowlarr.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "prowlarr.service" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${setupPkg}/bin/prowlarr-setup-indexers";
        NoNewPrivileges = true;
      };
    };
  };
}
