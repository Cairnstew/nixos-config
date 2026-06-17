{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  notifCfg = cfg.notifications;

  defaultMakoConf = ''
    background-color=#1e1e2e
    text-color=#cdd6f4
    border-color=#89b4fa
    border-radius=8
    border-size=2
    padding=10
    margin=8
    font=JetBrainsMono Nerd Font 11
    width=${toString notifCfg.width}
    height=120
    default-timeout=${toString notifCfg.defaultTimeout}
    [urgency=critical]
    border-color=#f38ba8
    default-timeout=0
  '';
in
{
  config = lib.mkIf (cfg.enable && notifCfg.enable) {
    environment.systemPackages = with pkgs; [ mako libnotify ];

    environment.etc."xdg/mako/config".text = defaultMakoConf;
  };
}
