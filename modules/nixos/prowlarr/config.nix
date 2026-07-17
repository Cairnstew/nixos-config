{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.prowlarr;
in
{
  config = lib.mkIf cfg.enable {
    services.prowlarr = {
      enable = true;
      inherit (cfg) package openFirewall;

      dataDir = cfg.dataDir;

      settings = lib.mkMerge [
        { server.port = cfg.port; }
        (lib.mkIf cfg.disableAnalytics { log.analyticsEnabled = false; })
      ];
    };
  };
}
