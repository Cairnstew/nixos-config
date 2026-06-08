{ lib, flake, config, ... }:
let
  inherit (lib) mkOption types mkDefault mkIf;
  cfg = config.my.deploy;
in
{
  imports = [
    ./tests.nix
  ];

  options.my.deploy = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the deploy ISO with embedded tailscale auth key and age private key.";
    };
  };

  config = mkIf cfg.enable {
    my.live.isos.deploy = {
      baseModule = mkDefault "minimal";
      system = mkDefault "x86_64-linux";
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
