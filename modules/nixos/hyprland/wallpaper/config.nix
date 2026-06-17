{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  wallCfg = cfg.wallpaper;

  wallpaperLines = if wallCfg.images != [ ] then
    lib.concatStringsSep "\n" (builtins.map (img: "preload = ${img}") wallCfg.images)
    + "\n" + lib.concatStringsSep "\n" (builtins.map (img: "wallpaper = ,${img}") wallCfg.images)
  else ''
    preload  = ${pkgs.hyprpaper}/share/hyprpaper/no-wallpaper.png
    wallpaper = ,${pkgs.hyprpaper}/share/hyprpaper/no-wallpaper.png
  '';

  defaultHyprpaperConf = wallpaperLines;
in
{
  config = lib.mkIf (cfg.enable && wallCfg.enable) {
    environment.systemPackages = with pkgs; [ hyprpaper ];

    environment.etc."xdg/hypr/hyprpaper.conf".text = defaultHyprpaperConf;
  };
}
