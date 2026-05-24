{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.services.tailscale;
  sec = config.my.secrets;
  me = flake.config.me;

  # Helper to get secret name from catalog (keys use dot notation like "tailscale.authKey")
  getSecretName = path: sec.catalog.${path}.name or null;

  # Get secret names from catalog (keys use dot notation)
  tailscaleAuthKeyName = getSecretName "tailscale.authKey";
  tailscaleSshKeyName = getSecretName "tailscale.sshKey";

  # Build static SSH config from config.nix tailnet data
  sshKeyPath =
    if tailscaleSshKeyName != null
    then config.age.secrets.${tailscaleSshKeyName}.path
    else null;

  # Generate SSH config content from static tailnet configuration
  generateSshConfig = hosts:
    lib.concatStringsSep "\n\n" (lib.mapAttrsToList
      (name: host: ''
        Host ${name}
          HostName ${host.magicDnsName}
          IdentityFile ${sshKeyPath}
          IdentitiesOnly yes
          ${cfg.ssh.extraHostConfig}
      '')
      hosts);

in
{
  config = mkIf cfg.enable (mkMerge [
    # ── Core VPN ──────────────────────────────────────────────────────────────
    {
      services.tailscale = {
        enable = true;
        openFirewall = cfg.openFirewall;
        authKeyFile = mkIf (sec.enable && tailscaleAuthKeyName != null)
          config.age.secrets.${tailscaleAuthKeyName}.path;
        extraUpFlags =
          [ "--accept-dns=true" ]
          ++ lib.optional (cfg.tags != [ ]) "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
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
    (mkIf (cfg.ssh.enable && sec.enable && tailscaleSshKeyName != null) {
      assertions = [
        {
          assertion = (sec.catalog."tailscale.sshKey".file or null) != null;
          message = "my.services.tailscale.ssh.enable requires tailscale.sshKey secret to be defined in my.secrets.catalog.";
        }
      ];

      age.secrets.${tailscaleSshKeyName}.owner = cfg.ssh.user;

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
