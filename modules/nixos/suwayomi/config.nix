{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.suwayomi;
in
{
  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "suwayomi") {
      suwayomi = {
        isSystemUser = true;
        group = cfg.group;
        description = "Suwayomi-Server service user";
        home = cfg.dataDir;
        createHome = true;
      };
    };

    users.groups = lib.mkIf (cfg.group == "suwayomi") {
      suwayomi = { };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.settings.server.port ];
  };
}
