{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  cpCfg = cfg.colorpicker;
in
{
  config = lib.mkIf (cfg.enable && cpCfg.enable) {
    environment.systemPackages = with pkgs; [ hyprpicker ];
  };
}
