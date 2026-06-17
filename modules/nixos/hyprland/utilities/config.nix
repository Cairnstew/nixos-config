{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  utilCfg = cfg.utilities;
in
{
  config = lib.mkIf (cfg.enable && utilCfg.enable) {
    security.polkit.enable = true;

    programs.nm-applet.enable = true;

    programs.thunar = {
      enable = true;
      plugins = with pkgs; [ thunar-archive-plugin thunar-volman ];
    };
    services.gvfs.enable = true;
    services.tumbler.enable = true;

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        liberation_ttf
      ];
      fontconfig.defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };

    environment.systemPackages = with pkgs; [
      polkit_gnome
      brightnessctl
      playerctl
      imv
      mpv
      xdg-utils
      xdg-user-dirs
      adwaita-icon-theme
      gnome-themes-extra
      gtk3
    ];

    environment.etc."xdg/gtk-3.0/settings.ini".text = ''
      [Settings]
      gtk-application-prefer-dark-theme=true
      gtk-cursor-theme-name=Adwaita
      gtk-cursor-theme-size=24
      gtk-font-name=Noto Sans 11
      gtk-icon-theme-name=Adwaita
      gtk-theme-name=Adwaita-dark
    '';
  };
}
