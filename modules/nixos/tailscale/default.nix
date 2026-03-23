{ config, lib, pkgs, ... }:

let
  inherit (lib)
    mkEnableOption mkOption mkIf mkMerge types literalExpression;

  cfg = config.my.services.tailscale;

  hasAuth   = cfg.authKeySecretFile != null;
  hasApi    = cfg.ssh.apiKeySecretFile != null;
  hasSshKey = cfg.ssh.sshKeySecretFile != null;
  hasSsh    = cfg.ssh.enable;

  authKeyPath   = config.age.secrets."tailscale-authkey".path;
  apiKeyPath    = config.age.secrets."tailscale-apikey".path;
  sshKeyPath    = config.age.secrets."tailscale-ssh-key".path;

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
      enable = mkEnableOption "Auto-generated ~/.ssh/config for tailnet machines";

      user = mkOption {
        type    = types.str;
        description = "Local user whose ~/.ssh/config will be managed.";
        example = "seanc";
      };

      sshConfigPath = mkOption {
        type = types.str;
        default = "~/.ssh/config"; # default to home directory
        description = ''
          Path where the tailscale-managed SSH config will be written.
          Can be overridden for WSL or read-only home directories.
        '';
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
        description = ''
          Extra lines appended verbatim to each generated Host block.
          Useful for setting ForwardAgent, ServerAliveInterval, etc.
        '';
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

      # Trust the Tailscale interface so all tailnet traffic flows freely.
      networking.firewall.trustedInterfaces = [ "tailscale0" ];

      # Forward .ts.net DNS queries to Tailscale's nameserver so MagicDNS
      # hostnames resolve correctly via systemd-resolved.
      services.resolved = {
        enable     = true;
        domains    = [ "~ts.net" ];
        extraConfig = ''
          [Resolve]
          DNS=100.100.100.100
          DNSStubListener=yes
        '';
      };
    }

    # ── SSH config generation ─────────────────────────────────────────────────
    (mkIf hasSsh {
      assertions = [
        {
          assertion = hasSshKey;
          message   = "my.services.tailscale.ssh.enable requires sshKeySecretFile to be set.";
        }
        {
          assertion = hasApi;
          message   = "my.services.tailscale.ssh.enable requires apiKeySecretFile to be set.";
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

      # Fetch the machine list and write ~/.ssh/config at every switch.
      system.activationScripts.tailscale-ssh-config = {
        deps = [ "agenix" ];
        text = ''
          set -euo pipefail

          ###############
          # Binaries
          ###############
          CURL=${pkgs.curl}/bin/curl
          JQ=${pkgs.jq}/bin/jq
          SED=${pkgs.gnused}/bin/sed
          GREP=${pkgs.gnugrep}/bin/grep
          MKDIR=${pkgs.coreutils}/bin/mkdir
          CHMOD=${pkgs.coreutils}/bin/chmod
          TOUCH=${pkgs.coreutils}/bin/touch
          MV=${pkgs.coreutils}/bin/mv
          CHOWN=${pkgs.coreutils}/bin/chown

          ###############
          # Paths and markers
          ###############
          SSH_CONFIG="${cfg.ssh.sshConfigPath}"
          SSH_DIR=$($SED 's/\/[^/]*$//' <<< "$SSH_CONFIG")  # dirname
          MARKER_START="# BEGIN tailscale-managed"
          MARKER_END="# END tailscale-managed"

          ###############
          # Environment variables for jq
          ###############
          export SSH_KEY="${sshKeyPath}"
          export EXTRA_HOST_CONFIG="${cfg.ssh.extraHostConfig}"

          ###############
          # Ensure directory & file exist
          ###############
          $MKDIR -p "$SSH_DIR"
          $CHMOD 700 "$SSH_DIR"

          $TOUCH "$SSH_CONFIG"
          $CHMOD 600 "$SSH_CONFIG"

          ###############
          # Fetch devices
          ###############
          API_KEY=$(cat ${apiKeyPath})

          echo "tailscale-ssh-config: fetching machine list..."
          response=$($CURL -sf -H "Authorization: Bearer $API_KEY" "https://api.tailscale.com/api/v2/tailnet/-/devices")

          ###############
          # Generate Host blocks
          ###############
          NEW_BLOCK=$($JQ -r '
            .devices[]
            | select(.hostname != null and .hostname != "")
            | "Host " + .hostname + "\n" +
              "  HostName " + .hostname + ".ts.net\n" +
              "  IdentityFile " + env.SSH_KEY + "\n" +
              "  IdentitiesOnly yes\n" +
              (if env.EXTRA_HOST_CONFIG != "" then
                  "  " + env.EXTRA_HOST_CONFIG + "\n"
              else
                  ""
              end)
          ' <<< "$response")

          ###############
          # Remove old managed block
          ###############
          if $GREP -q "$MARKER_START" "$SSH_CONFIG"; then
            BEFORE=$($SED "/$MARKER_START/,/$MARKER_END/d" "$SSH_CONFIG")
          else
            BEFORE=$(cat "$SSH_CONFIG")
          fi

          ###############
          # Write new config atomically
          ###############
          {
            printf '%s\n' "$BEFORE"
            echo ""
            echo "$MARKER_START"
            echo "$NEW_BLOCK"
            echo "$MARKER_END"
          } > "$SSH_CONFIG.tmp"

          $MV "$SSH_CONFIG.tmp" "$SSH_CONFIG"
          $CHOWN ${cfg.ssh.user}:users "$SSH_DIR" "$SSH_CONFIG"

          echo "tailscale-ssh-config: wrote $(echo "$NEW_BLOCK" | $GREP -c '^Host ') host entries to $SSH_CONFIG"
        '';
      };
    })
  ]);
}
