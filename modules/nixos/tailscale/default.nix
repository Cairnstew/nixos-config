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
        Generate at login.tailscale.com → Settings → Keys.
      '';
      example = literalExpression "flake.inputs.self + /secrets/tailscale-authkey.age";
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
      enable = mkEnableOption "Auto-generated SSH config fragment for tailnet machines";

      user = mkOption {
        type    = types.str;
        description = "Local user whose SSH config will be managed.";
        example = "seanc";
      };

      sshKeySecretFile = mkOption {
        type    = types.nullOr types.path;
        default = null;
        description = ''
          Path to the agenix-encrypted .age file containing the SSH private key
          used to connect to all tailnet machines.
        '';
        example = literalExpression "flake.inputs.self + /secrets/tailscale-ssh-key.age";
      };

      apiKeySecretFile = mkOption {
        type    = types.nullOr types.path;
        default = null;
        description = ''
          Path to the agenix-encrypted .age file containing a Tailscale API key
          (tskey-api-xxx) used to fetch the machine list at activation time.
          Generate at login.tailscale.com → Settings → Keys.
        '';
        example = literalExpression "flake.inputs.self + /secrets/tailscale-apikey.age";
      };

      extraHostConfig = mkOption {
        type    = types.lines;
        default = "";
        description = "Extra lines appended verbatim to each generated Host block.";
        example = "ForwardAgent yes";
      };

      sshPublicKeyFile = mkOption {
        type    = types.nullOr types.path;
        default = null;
        description = ''
          Path to the SSH public key file to add to authorized_keys for
          the configured user on this machine.
        '';
        example = literalExpression "flake.inputs.self + /secrets/tailscale_id.pub";
      };

      sshConfigPath = mkOption {
        type    = types.nullOr types.str;
        default = null;
        description = ''
          Path where the tailscale-managed SSH config fragment will be written.
          Defaults to ~/.ssh/config.d/tailscale for the configured user.
        '';
        example = "/run/ssh-seanc/config";
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
          [ "--accept-dns=true" ]
          ++ (lib.optional (cfg.tags != [])
            "--advertise-tags=${lib.concatStringsSep "," cfg.tags}")
          ++ (lib.optional cfg.exitNode "--advertise-exit-node");
      };

      # Trust the Tailscale interface so all tailnet traffic flows freely.
      networking.firewall.trustedInterfaces = [ "tailscale0" ];

      # Tell NetworkManager to hand DNS off to resolved rather than writing
      # /etc/resolv.conf directly.
      networking.networkmanager.dns = "systemd-resolved";
      environment.etc."resolv.conf".source =
        lib.mkForce "/run/systemd/resolve/stub-resolv.conf";

      # Forward .ts.net queries to Tailscale's nameserver (100.100.100.100)
      # so MagicDNS hostnames resolve correctly.
      services.resolved = {
        enable = true;
      };
    }

    # ── SSH config generation ─────────────────────────────────────────────────
    (mkIf hasSsh (
    let
      sshConfigPath =
        if cfg.ssh.sshConfigPath != null
        then cfg.ssh.sshConfigPath
        else "/home/${cfg.ssh.user}/.ssh/config.d/tailscale";
    in
    {
      assertions = [
        {
          assertion = hasSshKey;
          message   = "my.services.tailscale.ssh.enable requires ssh.sshKeySecretFile to be set.";
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

      age.secrets."tailscale-apikey" = {
        file  = cfg.ssh.apiKeySecretFile;
        owner = "root";
        mode  = "0400";
      };

      # Authorize the public key on this machine so other tailnet machines
      # can SSH in using the shared keypair.
      users.users.${cfg.ssh.user}.openssh.authorizedKeys.keyFiles =
        lib.optional (cfg.ssh.sshPublicKeyFile != null) cfg.ssh.sshPublicKeyFile;

      # Enable the home-manager SSH module and include the generated fragment.
      home-manager.users.${cfg.ssh.user}.my.services.ssh = {
        enable   = true;
        includes = [ "config.d/tailscale" ];
      };

      # Fetch the machine list and write the tailnet hosts into a separate
      # fragment, included from ~/.ssh/config via home-manager.
      system.activationScripts.tailscale-ssh-config = {
        deps = [ "agenix" ];
        text = ''
          set -euo pipefail

          SSH_CONFIG="${sshConfigPath}"
          SSH_DIR=$(dirname "$SSH_CONFIG")
          MARKER_START="# BEGIN tailscale-managed"
          MARKER_END="# END tailscale-managed"
          API_KEY=$(cat ${apiKeyPath})

          mkdir -p "$SSH_DIR"
          chmod 700 "$SSH_DIR"
          touch "$SSH_CONFIG"
          chmod 600 "$SSH_CONFIG"

          echo "tailscale-ssh-config: fetching machine list..."
          response=$(${pkgs.curl}/bin/curl -sf \
            -H "Authorization: Bearer $API_KEY" \
            "https://api.tailscale.com/api/v2/tailnet/-/devices")

          # Build Host blocks — .hostname as shortname, .name as FQDN
          NEW_BLOCK=$(echo "$response" | ${pkgs.jq}/bin/jq -r '
            .devices[]
            | select(.hostname != null and .hostname != "")
            | "Host " + .hostname + "\n" +
              "  HostName " + .name + "\n" +
              "  IdentityFile ${sshKeyPath}\n" +
              "  IdentitiesOnly yes\n" +
              "  ServerAliveInterval 60\n" +
              "  ServerAliveCountMax 5"
          ')

          # Preserve anything outside the managed markers
          if ${pkgs.gnugrep}/bin/grep -q "$MARKER_START" "$SSH_CONFIG" 2>/dev/null; then
            PRESERVED=$(${pkgs.gnused}/bin/sed "/$MARKER_START/,/$MARKER_END/d" "$SSH_CONFIG" \
              | ${pkgs.gnused}/bin/sed '/^[[:space:]]*$/d')
          else
            PRESERVED=$(cat "$SSH_CONFIG")
          fi

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

          COUNT=$(echo "$NEW_BLOCK" | ${pkgs.gnugrep}/bin/grep -c '^Host ' || true)
          echo "tailscale-ssh-config: wrote $COUNT host entries to $SSH_CONFIG"
        '';
      };
    }))
  ]);
}
