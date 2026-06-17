{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  portalCfg = cfg.portal;
in
{
  config = lib.mkIf (cfg.enable && portalCfg.enable) {
    xdg.portal = {
      enable = true;
      wlr.enable = false;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = [ "hyprland" "gtk" ];
    };
  };
}
