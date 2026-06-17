{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  nlCfg = cfg.nightLight;
in
{
  config = lib.mkIf (cfg.enable && nlCfg.enable) {
    environment.systemPackages = with pkgs; [ hyprsunset ];
  };
}
