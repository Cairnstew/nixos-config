{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  ssCfg = cfg.screenshot;
in
{
  config = lib.mkIf (cfg.enable && ssCfg.enable) {
    environment.systemPackages = with pkgs; [ grim slurp ];

    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/Pictures 0755 ${cfg.user} users -"
    ];
  };
}
