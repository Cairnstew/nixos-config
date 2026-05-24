{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.sillytavern;
  homeDir = "/var/lib/sillytavern";
in
{
  config = lib.mkIf cfg.enable {
    users.users = lib.mkIf (cfg.user == "sillytavern") {
      sillytavern = {
        isSystemUser = true;
        group = cfg.group;
        description = "SillyTavern service user";
        home = homeDir;
        createHome = true;
      };
    };

    users.groups = lib.mkIf (cfg.group == "sillytavern") {
      sillytavern = { };
    };
  };
}
