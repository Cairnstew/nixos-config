{ lib, flake, config, ... }:
let
  inherit (lib) mkDefault mkIf;
  cfg = config.my.deploy;
in
{
  config = mkIf cfg.enable {
    my.live.isos.deploy = {
      baseModule = mkDefault "minimal";
      hostPlatform = mkDefault "x86_64-linux";
      enableSSH = mkDefault true;
      enableFlakes = mkDefault true;
      squashfsCompression = mkDefault "gzip -Xcompression-level 1";
      isoName = mkDefault "nixos-deploy-x86_64.iso";
      volumeID = mkDefault "NIXOS_DEPLOY";
      ventoy = mkDefault true;

      sshKeys = [ flake.config.me.sshKey ];

      tailscale = {
        enable = mkDefault true;
        authKeyFile = mkDefault "/var/lib/tailscale/authkey";
        authKeyEncryptedSource = mkDefault (
          flake.inputs.self + /modules/nixos/secrets/tailscale-live-key.age
        );
      };

      extraContents = [
        {
          source = ./live-iso-ssh-key;
          target = "/var/lib/tailscale/live-iso-ssh-key";
        }
      ];
    };
  };
}
