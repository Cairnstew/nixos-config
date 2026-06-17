{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  clipCfg = cfg.clipboard;
in
{
  config = lib.mkIf (cfg.enable && clipCfg.enable) {
    environment.systemPackages = with pkgs; [
      wl-clipboard
    ] ++ lib.optionals clipCfg.history [ cliphist ];
  };
}
