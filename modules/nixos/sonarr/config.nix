{ config, lib, ... }:
let
  cfg = config.my.services.sonarr;
in
{
  config = lib.mkIf cfg.enable {
    services.sonarr = {
      enable = true;
      inherit (cfg) package dataDir user group openFirewall;

      settings = lib.mkMerge [
        { server.port = cfg.port; }
        (lib.mkIf cfg.disableAnalytics { log.analyticsEnabled = false; })
      ];
    };

    systemd.services.sonarr.serviceConfig = {
      StateDirectory = "sonarr";
      StateDirectoryMode = "0750";
    };
  };
}
