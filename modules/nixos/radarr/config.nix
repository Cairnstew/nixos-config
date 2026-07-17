{ config, lib, ... }:
let
  cfg = config.my.services.radarr;
in
{
  config = lib.mkIf cfg.enable {
    services.radarr = {
      enable = true;
      inherit (cfg) package dataDir user group openFirewall;

      settings = lib.mkMerge [
        { server.port = cfg.port; }
        (lib.mkIf cfg.disableAnalytics { log.analyticsEnabled = false; })
      ];
    };
  };
}
