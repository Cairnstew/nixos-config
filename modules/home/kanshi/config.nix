{ config, lib, ... }:
let
  cfg = config.my.services.kanshi;
in
{
  config = lib.mkIf cfg.enable {
    services.kanshi = {
      enable = true;
      package = cfg.package;
      settings = cfg.settings;
      systemdTarget = cfg.systemdTarget;
    };
  };
}
