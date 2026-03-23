{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption mkOption mkIf mkMerge types literalExpression;

  cfg = config.my.services.tailscale;

  hasAuth   = cfg.authKeySecretFile != null;
  hasApi    = cfg.ssh.apiKeySecretFile != null;
  hasSshKey = cfg.ssh.sshKeySecretFile != null;
  hasSsh    = cfg.ssh.enable;

  authKeyPath = config.age.secrets."tailscale-authkey".path;
  apiKeyPath  = config.age.secrets."tailscale-apikey".path;
  sshKeyPath  = config.age.secrets."tailscale-ssh-key".path;

  tagsJson = builtins.toJSON cfg.tags;

  # Script that writes the SSH config from the Tailscale API.
  # Runs as a systemd service so it retries and has proper ordering.
  sshConfigScript = pkgs.writeShellScript "tailscale-ssh-config" ''
    set -euo pipefail

    SSH_CONFIG="${cfg.ssh.sshConfigPath}"
    SSH_DIR=$(dirname "$SSH_CONFIG")
    MARKER_START="# BEGIN tailscale-managed"
    MARKER_END="# END tailscale-managed"

    # Ensure directory and file exist with correct permissions
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"

    # Wait until Tailscale is authenticated
    echo "Waiting for Tailscale to be authenticated..."
    for i in $(seq 1 30); do
      STATUS=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r '.BackendState' 2>/dev/null || echo "unknown")
      if [ "$STATUS" = "Running" ]; then
        break
      fi
      echo "  Tailscale state: $STATUS — waiting... ($i/30)"
      sleep 2
    done

    if [ "$STATUS" != "Running" ]; then
      echo "ERROR: Tailscale not running after 60s, skipping SSH config generation."
      exit 1
    fi

    echo "Fetching machine list from Tailscale API..."
    API_KEY=$(cat ${apiKeyPath})

    response=$(${pkgs.curl}/bin/curl -sf \
      -H "Authorization: Bearer $API_KEY" \
      "https://api.tailscale.com/api/v2/tailnet/-/devices")

    # Generate Host blocks for each device
    NEW_BLOCK=$(echo "$response" | ${pkgs.jq}/bin/jq -r '
      .devices[]
      | select(.hostname != null and .hostname != "")
      | "Host " + .hostname + "\n" +
        "  HostName " + .hostname + ".ts.net\n" +
        "  User ${cfg.ssh.user}\n" +
        "  IdentityFile ${sshKeyPath}\n" +
        "  IdentitiesOnly yes\n" +
        "  ServerAliveCountMax 5\n" +
        "  ServerAliveInterval 60"
    ')

    ${lib.optionalString (cfg.ssh.extraHostConfig != "") ''
      # Append extra host config to each block
      NEW_BLOCK=$(echo "$NEW_BLOCK" | ${pkgs.gnused}/bin/sed '/^Host /{ n; }' )
    ''}

    # Remove old managed block, preserve everything else
    if grep -q "$MARKER_START" "$SSH_CONFIG"; then
      PRESERVED=$(sed "/$MARKER_START/,/$MARKER_END/d" "$SSH_CONFIG" | sed '/^$/d')
    else
      PRESERVED=$(cat "$SSH_CONFIG")
    fi

    # Write new config atomically
    {
      if [ -n "$PRESERVED" ]; then
        echo "$PRESERVED"
        echo ""
      fi
      echo "$MARKER_START"
      echo "$NEW_BLOCK"
      echo "$MARKER_END"
    } > "$SSH_CONFIG.tmp"

    mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"
    chown ${cfg.ssh.user}:users "$SSH_DIR" "$SSH_CONFIG"

    COUNT=$(echo "$NEW_BLOCK" | grep -c '^Host ' || true)
    echo "Wrote $COUNT host entries to $SSH_CONFIG"
  '';

in
{
  # ── Options ────────────────────────────────────────────────────────────────
  options.my.services.tailscale = {
    enable = mkEnableOption "Tailscale mesh VPN";

    authKeySecretFile = mkOption {
      type    = types.nullOr types.path;
      default = null;
      description = ''
        Path to the agenix-encrypted .age file containing the Tailscale
        auth key (tskey-auth-xxx). The module declares age.secrets automatically.
        Generate via bootstrap-tailscale or at login.tailscale.com → Settings → Keys.
      '';
      example = literalExpression "flake.inputs.self + /secrets/tailscale-authkey.age";
    };

    policyFile = mkOption {
      type    = types.nullOr types.path;
      default = null;
      description = ''
        Path to a JSON file containing the Tailscale tailnet policy
        (grants, tagOwners, SSH rules). Applied via apply-tailscale-policy.
      '';
      example = literalExpression "flake.inputs.self + /tailscale-policy.json";
    };

    tags = mkOption {
      type    = types.listOf types.str;
      default = [];
      example = [ "tag:nixos" "tag:personal" ];
      description = "Tailscale tags to advertise for this machine.";
    };

    exitNode = mkOption {
      type    = types.bool;
      default = false;
      description = "Whether to advertise this machine as a Tailscale exit node.";
    };

    openFirewall = mkOption {
      type    = types.bool;
      default = true;
      description = "Open the Tailscale UDP port in the firewall.";
    };

    # ── SSH sub-options ──────────────────────────────────────────────────────
    ssh = {
      enable = mkEnableOption "Auto-generated ~/.ssh/config for tailnet machines";

      user = mkOption {
        type    = types.str;
        description = "Local user whose ~/.ssh/config will be managed.";
        example = "seanc";
      };

      sshConfigPath = mkOption {
        type    = types.str;
        default = "/home/${cfg.ssh.user}/.ssh/config";
        description = ''
          Path where the tailscale-managed SSH config will be written.
          Defaults to ~/.ssh/config for the specified user.
        '';
      };

      sshKeySecretFile = mkOption {
        type    = types.nullOr types.path;
        default = null;
        description = ''
          Path to the agenix-encrypted .age file for the SSH private key
          used to connect to all tailnet machines.
        '';
        example = literalExpression "flake.inputs.self + /secrets/tailscale-ssh-key.age";
      };

      apiKeySecretFile = mkOption {
        type    = types.nullOr types.path;
        default = null;
        description = ''
          Path to the agenix-encrypted .age file for the Tailscale API key
          (tskey-api-xxx). Used to fetch the device list.
          Generate at login.tailscale.com → Settings → Keys.
        '';
        example = literalExpression "flake.inputs.self + /secrets/tailscale-apikey.age";
      };

      extraHostConfig = mkOption {
        type    = types.lines;
        default = "";
        description = "Extra lines appended to each generated Host block.";
        example = "ForwardAgent yes";
      };
    };
  };

  # ── Implementation ─────────────────────────────────────────────────────────
  config = mkIf cfg.enable (mkMerge [

    # ── VPN ───────────────────────────────────────────────────────────────────
    {
      age.secrets."tailscale-authkey" = mkIf hasAuth {
        file  = cfg.authKeySecretFile;
        owner = "root";
        mode  = "0400";
      };

      services.tailscale = {
        enable       = true;
        openFirewall = cfg.openFirewall;
        authKeyFile  = mkIf hasAuth authKeyPath;
        extraUpFlags =
          (lib.optional (cfg.tags != [])
            "--advertise-tags=${lib.concatStringsSep "," cfg.tags}")
          ++ (lib.optional cfg.exitNode "--advertise-exit-node");
      };

      # Trust tailscale interface so all tailnet traffic flows freely.
      networking.firewall.trustedInterfaces = [ "tailscale0" ];

      # Route .ts.net DNS queries to Tailscale's MagicDNS nameserver.
      services.resolved = {
        enable      = true;
        domains     = [ "~ts.net" ];
        extraConfig = ''
          [Resolve]
          DNS=100.100.100.100
          DNSStubListener=yes
        '';
      };
    }

    # ── Bootstrap + policy scripts (only when API key is configured) ──────────
    (mkIf hasApi {
      age.secrets."tailscale-apikey" = {
        file  = cfg.ssh.apiKeySecretFile;
        owner = "root";
        mode  = "0400";
      };

      environment.systemPackages = lib.optionals true [

        # Push the policy JSON to Tailscale via the API.
        # Run this before bootstrapping so tagOwners are defined.
        (mkIf (cfg.policyFile != null) (pkgs.writeShellScriptBin "apply-tailscale-policy" ''
          set -euo pipefail
          API_KEY=$(cat ${apiKeyPath})
          echo "Applying Tailscale policy from ${toString cfg.policyFile}..."
          response=$(${pkgs.curl}/bin/curl -sf \
            -X POST https://api.tailscale.com/api/v2/tailnet/-/acl \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d @${cfg.policyFile})
          echo "Done."
          echo "$response" | ${pkgs.jq}/bin/jq . 2>/dev/null || echo "$response"
        ''))

        # One-time bootstrap:
        #   1. Push policy (defines tagOwners)
        #   2. Generate a reusable non-expiring tagged auth key
        #   3. Print key to encrypt with agenix
        (pkgs.writeShellScriptBin "bootstrap-tailscale" ''
          set -euo pipefail
          API_KEY=$(cat ${apiKeyPath})

          ${lib.optionalString (cfg.policyFile != null) ''
            echo "Step 1/2: Applying policy..."
            ${pkgs.curl}/bin/curl -sf \
              -X POST https://api.tailscale.com/api/v2/tailnet/-/acl \
              -H "Authorization: Bearer $API_KEY" \
              -H "Content-Type: application/json" \
              -d @${cfg.policyFile} > /dev/null
            echo "Policy applied."
            echo ""
          ''}

          echo "Generating reusable auth key with tags ${tagsJson}..."
          response=$(${pkgs.curl}/bin/curl -sf \
            -X POST https://api.tailscale.com/api/v2/tailnet/-/keys \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
              \"capabilities\": {
                \"devices\": {
                  \"create\": {
                    \"reusable\": true,
                    \"preauthorized\": true,
                    \"ephemeral\": false,
                    \"tags\": ${tagsJson}
                  }
                }
              },
              \"expirySeconds\": 0
            }")

          auth_key=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.key')

          echo ""
          echo "Auth key generated successfully:"
          echo ""
          echo "  $auth_key"
          echo ""
          echo "Encrypt it with agenix:"
          echo "  agenix -e secrets/tailscale-authkey.age"
          echo "  (paste the key above, save and exit)"
          echo ""
          echo "Then rebuild: nix run"
        '')
      ];
    })

    # ── SSH config generation ─────────────────────────────────────────────────
    (mkIf hasSsh {
      assertions = [
        {
          assertion = hasSshKey;
          message   = "my.services.tailscale.ssh.enable requires sshKeySecretFile to be set.";
        }
        {
          assertion = hasApi;
          message   = "my.services.tailscale.ssh.enable requires ssh.apiKeySecretFile to be set.";
        }
      ];

      age.secrets."tailscale-ssh-key" = {
        file  = cfg.ssh.sshKeySecretFile;
        owner = cfg.ssh.user;
        mode  = "0400";
      };

      # Systemd service — runs after tailscaled is up, retries on failure.
      # Much more reliable than an activation script for network-dependent tasks.
      systemd.services.tailscale-ssh-config = {
        description = "Generate ~/.ssh/config entries for Tailscale machines";
        wantedBy    = [ "multi-user.target" ];
        after       = [ "tailscaled.service" "network-online.target" ];
        wants       = [ "network-online.target" ];
        requires    = [ "tailscaled.service" ];

        # Re-run whenever the system switches to a new config.
        restartTriggers = [ sshConfigScript ];

        serviceConfig = {
          Type            = "oneshot";
          RemainAfterExit = true;
          ExecStart       = sshConfigScript;
          Restart         = "on-failure";
          RestartSec      = "10s";
          # Allow enough time for Tailscale to authenticate.
          TimeoutStartSec = "120s";
        };
      };
    })
  ]);
}
