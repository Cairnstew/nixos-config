{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.services.tailscale;
  me = flake.config.me;
in
{
  config = mkIf cfg.enable (mkMerge [
    # ── Core VPN ──────────────────────────────────────────────────────────────
    {
      services.tailscale = {
        enable = true;
        openFirewall = cfg.openFirewall;
        authKeyFile = config.age.secrets.tailscale-authkey.path;
        extraUpFlags =
          [ "--accept-dns=true" ]
          ++ lib.optional (cfg.tags != [ ]) "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
          ++ lib.optional cfg.exitNode "--advertise-exit-node"
          ++ lib.optional cfg.acceptRoutes "--accept-routes"
          ++ lib.optional cfg.ssh.enable "--ssh";
      };

      networking.firewall.trustedInterfaces = [ "tailscale0" ];
      networking.networkmanager.dns = "systemd-resolved";
      environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/stub-resolv.conf";
      services.resolved.enable = true;

      # Ensure tailscaled starts reliably
      systemd.services.tailscaled = {
        after = [ "network-pre.target" "systemd-resolved.service" ];
        wants = [ "network-pre.target" "systemd-resolved.service" ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = "5";
        };
      };

      # tailscale-manager needs tailscaled active before it can reach the API
      systemd.services.tailscale-manager = mkIf config.my.services.tailscale.manager.enable {
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
      };
    }

    # ── SSH config generation (live from tailscale status) ────────────────────
    (mkIf cfg.ssh.enable {

      users.users.${cfg.ssh.user}.openssh.authorizedKeys.keyFiles =
        lib.optional (cfg.ssh.publicKeyPath != null) cfg.ssh.publicKeyPath;

      home-manager.users.${cfg.ssh.user} = {
        my.services.ssh = {
          enable = true;
          includes = [ "config.d/tailscale" ];
        };
      };

      # Runtime SSH config generator — fetches live device list from tailscale status
      # Gracefully handles the case where tailscale isn't authenticated yet
      systemd.services.tailscale-ssh-config = {
        description = "Generate SSH config from live tailscale device list";
        after = [ "tailscaled.service" "network-online.target" ];
        wants = [ "tailscaled.service" "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "30";
          ExecStart =
            let
              sshKey = if cfg.ssh.identityFile != null then toString cfg.ssh.identityFile else "";
            in
            pkgs.writeShellScript "tailscale-ssh-config" ''
              set -uo pipefail

              SSH_DIR="/home/${cfg.ssh.user}/.ssh/config.d"
              SSH_FILE="$SSH_DIR/tailscale"
              SSH_KEY="${sshKey}"
              EXTRA="${cfg.ssh.extraHostConfig}"

              mkdir -p "$SSH_DIR"

              cat > "$SSH_FILE" << 'EOF'
              # BEGIN tailscale-managed — generated from live tailscale status
              # Do not edit manually. Regenerate: systemctl start tailscale-ssh-config

              EOF

              # Capture tailscale status — may fail if not authenticated yet
              TS_STATUS=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null || true)

              if [ -n "$TS_STATUS" ]; then
                echo "$TS_STATUS" | ${pkgs.jq}/bin/jq \
                  --arg key "$SSH_KEY" \
                  --arg extra "$EXTRA" -r '
                  def clean: rtrimstr(".");
                  def short: split(".")[0];
                  def identityBlock:
                    if $key != "" then
                      "  IdentityFile \($key)",
                      "  IdentitiesOnly yes"
                    else empty end;
                  [.Self, (.Peer // {})[]] | .[] | select(. != null and .DNSName != null) |
                    "Host \(.DNSName | short)",
                    "  HostName \(.DNSName | clean)",
                    identityBlock,
                    (if $extra != "" then "  \($extra)" else "" end),
                    "",
                    "Host \(.DNSName | clean)",
                    "  HostName \(.DNSName | clean)",
                    identityBlock,
                    (if $extra != "" then "  \($extra)" else "" end),
                    ""
                ' >> "$SSH_FILE" 2>/dev/null || true
              fi

              chmod 644 "$SSH_FILE"
            '';
        };
      };
    })
  ]);
}
