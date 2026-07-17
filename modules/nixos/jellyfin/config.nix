{ config, lib, ... }:
let
  cfg = config.my.services.jellyfin;
in
{
  config = lib.mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      inherit (cfg) package dataDir configDir cacheDir user group openFirewall;
    };

    systemd.services.jellyfin.serviceConfig = lib.mkIf (cfg.mediaDirs != [ ]) {
      BindReadOnlyPaths = cfg.mediaDirs;
    };
  };
}
