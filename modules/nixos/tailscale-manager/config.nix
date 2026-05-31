{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkDefault;
  cfg = config.my.services.tailscale-manager;
  sec = config.my.secrets;

  getSecretName = path: sec.catalog.${path}.name or null;
  tailscaleManagerOauthName = getSecretName "tailscale-manager.oauth";
in
{
  config = mkIf cfg.enable {
    services.tailscale-manager = {
      enable = true;
      tailnet = cfg.tailnet;
      tags = cfg.tags;
      stateDir = cfg.stateDir;
      backupCount = cfg.backupCount;
      watchCredentials = cfg.watchCredentials;

      credentialsFile = mkIf (sec.enable && tailscaleManagerOauthName != null)
        config.age.secrets.${tailscaleManagerOauthName}.path;
    };

    age.secrets = mkIf (sec.enable && tailscaleManagerOauthName != null) {
      ${tailscaleManagerOauthName} = {
        file = sec.catalog."tailscale-manager.oauth".file;
        owner = "root";
        group = "root";
        mode = "0400";
      };
    };

    systemd.services.tailscale-manager = {
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
    };
  };
}
