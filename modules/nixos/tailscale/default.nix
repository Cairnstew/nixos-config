{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;

  cfg = config.my.services.tailscale;
  sec = config.my.secrets;

  # Derive the actual runtime paths only when secrets are active.
  authKeyPath = mkIf sec.enable sec.tailscale.authKey;
  apiKeyPath  = config.age.secrets.${sec.names.tailscale.apiKey}.path;
  sshKeyPath  = config.age.secrets.${sec.names.tailscale.sshKey}.path;

  sshConfigPath =
    if cfg.ssh.sshConfigPath != null
    then cfg.ssh.sshConfigPath
    else "/home/${cfg.ssh.user}/.ssh/config.d/tailscale";

in
{
  imports = [ ../secrets/default.nix ];

  # ── Options ──────────────────────────────────────────────────────────────
  options.my.services.tailscale = {
    enable      = mkEnableOption "Tailscale mesh VPN";
    openFirewall = mkOption { type = types.bool; default = true; description = "Open the Tailscale UDP port in the firewall."; };
    exitNode    = mkOption { type = types.bool; default = false; description = "Advertise this machine as a Tailscale exit node."; };

    tags = mkOption {
      type    = types.listOf types.str;
      default = [];
      example = [ "tag:nixos" "tag:personal" ];
      description = "Tailscale ACL tags to advertise for this machine.";
    };

    ssh = {
      enable = mkEnableOption "Auto-generated SSH config fragment for tailnet machines";

      user = mkOption {
        type        = types.str;
        description = "Local user whose SSH config will be managed.";
        example     = "alice";
      };

      publicKeyPath = mkOption {
        type        = types.nullOr types.path;
        default     = null;
        description = "Path to the Tailscale SSH public key to authorise on this host.";
        example     = "/etc/ssh/tailscale_id.pub";
      };

      sshConfigPath = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        description = "Override destination path for the generated fragment. Defaults to ~/.ssh/config.d/tailscale.";
        example     = "/run/ssh-alice/tailscale";
      };

      extraHostConfig = mkOption {
        type        = types.lines;
        default     = "";
        description = "Extra lines appended verbatim inside every generated Host block.";
        example     = "ForwardAgent yes";
      };
    };
  };

  # ── Implementation ────────────────────────────────────────────────────────
  config = mkIf cfg.enable (mkMerge [

    # ── Core VPN ─────────────────────────────────────────────────────────────
    {
      services.tailscale = {
        enable       = true;
        openFirewall = cfg.openFirewall;
        authKeyFile  = mkIf sec.enable
          config.age.secrets.${sec.names.tailscale.authKey}.path;
        extraUpFlags =
          [ "--accept-dns=true" ]
          ++ lib.optional (cfg.tags    != [])  "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
          ++ lib.optional  cfg.exitNode         "--advertise-exit-node";
      };

      networking.firewall.trustedInterfaces    = [ "tailscale0" ];
      networking.networkmanager.dns            = "systemd-resolved";
      environment.etc."resolv.conf".source     = lib.mkForce "/run/systemd/resolve/stub-resolv.conf";
      services.resolved.enable                 = true;
    }

    # ── SSH config generation ─────────────────────────────────────────────────
    (mkIf (cfg.ssh.enable && sec.enable) {

      assertions = [
        {
          assertion = sec.tailscale.sshKey != null;
          message   = "my.services.tailscale.ssh.enable requires my.secrets.tailscale.sshKey to be set.";
        }
        {
          assertion = sec.tailscale.apiKey != null;
          message   = "my.services.tailscale.ssh.enable requires my.secrets.tailscale.apiKey to be set.";
        }
      ];

      # Set the SSH key secret owner to the configured user.
      age.secrets.${sec.names.tailscale.sshKey}.owner = cfg.ssh.user;

      # Authorise the shared public key on this host.
      users.users.${cfg.ssh.user}.openssh.authorizedKeys.keyFiles =
        lib.optional (cfg.ssh.publicKeyPath != null) cfg.ssh.publicKeyPath;

      # Pull the generated fragment into the user's SSH config.
      home-manager.users.${cfg.ssh.user}.my.services.ssh = {
        enable   = true;
        includes = [ "config.d/tailscale" ];
      };

      # Write a Host block per tailnet machine, preserving non-managed lines.
      systemd.services.tailscale-ssh-config = {
        description = "Generate SSH config from Tailscale API";

        after = [
          "network-online.target"
          "tailscaled.service"
        ];

        wants = [ "network-online.target" ];

        serviceConfig = {
          Type = "oneshot";
          User = cfg.ssh.user;
          ExecStart = pkgs.writeShellScript "tailscale-ssh-config" ''
            set -euo pipefail

            SSH_CONFIG="${sshConfigPath}"
            SSH_DIR=$(dirname "$SSH_CONFIG")
            MARKER_START="# BEGIN tailscale-managed"
            MARKER_END="# END tailscale-managed"

            if ! API_KEY=$(cat ${apiKeyPath} 2>/dev/null); then
              echo "tailscale-ssh-config: WARNING: cannot read API key, skipping." >&2
              exit 0
            fi

            mkdir -p "$SSH_DIR"
            chmod 700 "$SSH_DIR"
            touch "$SSH_CONFIG"
            chmod 600 "$SSH_CONFIG"

            echo "tailscale-ssh-config: fetching machine list…"

            response=$(${pkgs.curl}/bin/curl -sf \
              -H "Authorization: Bearer $API_KEY" \
              "https://api.tailscale.com/api/v2/tailnet/-/devices")

            NEW_BLOCK=$(echo "$response" | ${pkgs.jq}/bin/jq -r '
              .devices[]
              | select(.hostname != null and .hostname != "")
              | "Host " + .hostname
              + "\n  HostName " + .name
              + "\n  IdentityFile ${sshKeyPath}"
              + "\n  IdentitiesOnly yes"
              + "\n"
            ')

            echo "$MARKER_START" > "$SSH_CONFIG"
            echo "$NEW_BLOCK" >> "$SSH_CONFIG"
            echo "$MARKER_END" >> "$SSH_CONFIG"
          '';
        };

        wantedBy = [ "multi-user.target" ];
      };
    })
  ]);
}