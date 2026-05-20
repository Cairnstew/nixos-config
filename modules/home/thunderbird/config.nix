{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.thunderbird;
in
{
  config = lib.mkIf cfg.enable {
    programs.thunderbird = {
      enable = true;
      package = cfg.package;
      profiles.${cfg.profileName} = {
        isDefault = true;
        settings = cfg.settings;
      };
    };
  };
}
