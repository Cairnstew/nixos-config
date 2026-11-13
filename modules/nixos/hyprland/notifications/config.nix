{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  notifCfg = cfg.notifications;
in
{
  config = lib.mkIf (cfg.enable && notifCfg.enable) {
    environment.systemPackages = with pkgs; [ mako libnotify ];
    # The mako config file itself is written by ./theme.nix (all colour code
    # lives there).
  };
}
