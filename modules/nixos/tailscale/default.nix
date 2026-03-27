{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types;

  cfg = config.my.services.tailscale;
  sec = config.my.secrets;

  apiKeyPath = config.age.secrets.${sec.names.tailscale.apiKey}.path;
  sshKeyPath = config.age.secrets.${sec.names.tailscale.sshKey}.path;

  sshConfigPath =
    if cfg.ssh.sshConfigPath != null
    then cfg.ssh.sshConfigPath
    else "/home/${cfg.ssh.user}/.ssh/config.d/tailscale";

  # The script is a derivation so sshKeyPath / sshConfigPath are
  # baked in at eval time — no runtime secret-path guessing needed.
  generatorScript = pkgs.writeShellScript "tailscale-ssh-config" ''
    set -euo pipefail

    SSH_CONFIG="${sshConfigPath}"
    SSH_DIR=$(dirname "$SSH_CONFIG")

    # ── Read secrets ────────────────────────────────────────────────────────
    if ! API_KEY=$(cat "${apiKeyPath}" 2>/dev/null); then
      echo "tailscale-ssh-config: ERROR: cannot read API key at ${apiKeyPath}" >&2
      exit 1
    fi

    # ── Fetch device list with retry ────────────────────────────────────────
    response=""
    for attempt in 1 2 3; do
      if response=$(${pkgs.curl}/bin/curl -sf --max-time 10 \
          -H "Authorization: Bearer $API_KEY" \
          "https://api.tailscale.com/api/v2/tailnet/-/devices"); then
        break
      fi
      echo "tailscale-ssh-config: attempt $attempt failed, retrying…" >&2
      sleep $((attempt * 5))
    done

    if [ -z "$response" ]; then
      echo "tailscale-ssh-config: ERROR: failed to fetch device list after 3 attempts" >&2
      exit 1
    fi

    # ── Build host blocks ───────────────────────────────────────────────────
    NEW_BLOCK=$(echo "$response" | ${pkgs.jq}/bin/jq -r '
      .devices[]
      | select(.hostname != null and .hostname != "")
      | "Host " + .hostname
      + "\n  HostName " + .name
      + "\n  IdentityFile ${sshKeyPath}"
      + "\n  IdentitiesOnly yes"
      + "${lib.optionalString (cfg.ssh.extraHostConfig != "")
          "\\n  ${lib.replaceStrings ["\n"] ["\\n  "] cfg.ssh.extraHostConfig}"}"
    ')

    # ── Write atomically ────────────────────────────────────────────────────
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    TMPFILE=$(mktemp "$SSH_DIR/.tailscale.XXXXXX")
    trap 'rm -f "$TMPFILE"' EXIT

    {
      echo "# BEGIN tailscale-managed"
      echo "$NEW_BLOCK"
      echo "# END tailscale-managed"
    } > "$TMPFILE"

    chmod 600 "$TMPFILE"
    mv "$TMPFILE" "$SSH_CONFIG"

    echo "tailscale-ssh-config: wrote $(echo "$NEW_BLOCK" | grep -c '^Host ') host(s) to $SSH_CONFIG"
  '';

in
{
  imports = [ ../secrets/default.nix ];

  options.my.services.tailscale = {
    enable       = mkEnableOption "Tailscale mesh VPN";
    openFirewall = mkOption { type = types.bool; default = true;  description = "Open the Tailscale UDP port in the firewall."; };
    exitNode     = mkOption { type = types.bool; default = false; description = "Advertise this machine as a Tailscale exit node."; };

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
      };

      sshConfigPath = mkOption {
        type        = types.nullOr types.str;
        default     = null;
        description = "Override destination path for the generated fragment. Defaults to ~/.ssh/config.d/tailscale.";
      };

      extraHostConfig = mkOption {
        type        = types.lines;
        default     = "";
        description = "Extra lines appended inside every generated Host block (e.g. 'ForwardAgent yes').";
        example     = "ForwardAgent yes\nServerAliveInterval 60";
      };

      refreshInterval = mkOption {
        type        = types.str;
        default     = "1h";
        description = "How often to refresh the SSH config from the Tailscale API (systemd calendar interval).";
        example     = "30min";
      };
    };
  };

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
          ++ lib.optional (cfg.tags   != []) "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
          ++ lib.optional  cfg.exitNode       "--advertise-exit-node";
      };

      networking.firewall.trustedInterfaces = [ "tailscale0" ];
      networking.networkmanager.dns         = "systemd-resolved";
      environment.etc."resolv.conf".source  = lib.mkForce "/run/systemd/resolve/stub-resolv.conf";
      services.resolved.enable              = true;
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

      age.secrets.${sec.names.tailscale.sshKey}.owner = cfg.ssh.user;

      users.users.${cfg.ssh.user}.openssh.authorizedKeys.keyFiles =
        lib.optional (cfg.ssh.publicKeyPath != null) cfg.ssh.publicKeyPath;

      home-manager.users.${cfg.ssh.user}.my.services.ssh = {
        enable   = true;
        includes = [ "config.d/tailscale" ];
      };

      # ── One-shot service ──────────────────────────────────────────────────
      systemd.services.tailscale-ssh-config = {
        description = "Generate SSH config from Tailscale API";
        after       = [ "network-online.target" "tailscaled.service" ];
        wants       = [ "network-online.target" ];
        serviceConfig = {
          Type      = "oneshot";
          User      = cfg.ssh.user;
          ExecStart = generatorScript;
          Restart   = "no";
        };
      };


      # ── Timer for periodic refresh ────────────────────────────────────────
      systemd.timers.tailscale-ssh-config = {
        description = "Periodically refresh Tailscale SSH config";
        wantedBy    = [ "timers.target" ];
        timerConfig = {
          OnActiveSec         = "30s";       # first run shortly after boot
          OnUnitActiveSec   = cfg.ssh.refreshInterval;
          RandomizedDelaySec = "60s";      # avoid thundering herd across hosts
          Persistent        = true;        # catch up if the machine was off
        };
      };
    })
  ]);
}