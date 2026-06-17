{ config, lib, ... }:
let
  cfg = config.my.desktop.hyprland;
  launchCfg = cfg.launcher;
in
{
  config = lib.mkIf (cfg.enable && launchCfg.enable) {
    environment.systemPackages = [ launchCfg.package ];
  };
}
