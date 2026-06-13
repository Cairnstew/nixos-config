{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.suwayomi;
in
{
  config = lib.mkMerge [
    # Always create the suwayomi user/group so agenix chown of suwayomi-password
    # succeeds even when the service is disabled on this host.
    (lib.mkIf (cfg.user == "suwayomi") {
      users.users.suwayomi = {
        isSystemUser = true;
        group = cfg.group;
        description = "Suwayomi-Server service user";
        home = cfg.dataDir;
        createHome = true;
      };
    })

    (lib.mkIf (cfg.group == "suwayomi") {
      users.groups.suwayomi = { };
    })

    (lib.mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.settings.server.port ];
    })
  ];
}
