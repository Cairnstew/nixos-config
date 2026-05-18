{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.services.tailscale;
  sec = config.my.secrets;
  me = flake.config.me;

  # Build static SSH config from config.nix tailnet data
  sshKeyPath = config.age.secrets.${sec.names.tailscale.sshKey}.path;

  # Generate SSH config content from static tailnet configuration
  generateSshConfig = hosts:
    lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: host: ''
      Host ${name}
        HostName ${host.magicDnsName}
        IdentityFile ${sshKeyPath}
        IdentitiesOnly yes
        ${cfg.ssh.extraHostConfig}
    '') hosts);

in
{
  config = mkIf cfg.enable (mkMerge [
    # ── Core VPN ──────────────────────────────────────────────────────────────
    {
      services.tailscale = {
        enable = true;
        openFirewall = cfg.openFirewall;
        authKeyFile = mkIf sec.enable
          config.age.secrets.${sec.names.tailscale.authKey}.path;
        extraUpFlags =
          [ "--accept-dns=true" ]
          ++ lib.optional (cfg.tags != []) "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
          ++ lib.optional cfg.exitNode "--advertise-exit-node";
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
    }

    # ── SSH config generation ────────────────────────────────────────────────
    (mkIf (cfg.ssh.enable && sec.enable) {
      assertions = [
        {
          assertion = sec.tailscale.sshKey != null;
          message = "my.services.tailscale.ssh.enable requires my.secrets.tailscale.sshKey to be set.";
        }
      ];

      age.secrets.${sec.names.tailscale.sshKey}.owner = cfg.ssh.user;

      users.users.${cfg.ssh.user}.openssh.authorizedKeys.keyFiles =
        lib.optional (cfg.ssh.publicKeyPath != null) cfg.ssh.publicKeyPath;

      home-manager.users.${cfg.ssh.user} = {
        my.services.ssh = {
          enable = true;
          includes = [ "config.d/tailscale" ];
        };

        # Static SSH config file generated at build time
        home.file.".ssh/config.d/tailscale".text = ''
          # BEGIN tailscale-managed — do not edit, generated at build time
          # Static configuration from config.nix tailnet entries

          ${generateSshConfig flake.config.tailnet}

          # END tailscale-managed
        '';
      };
    })
  ]);
}
