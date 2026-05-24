{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.programs.ghostty;
  prefs = flake.config.preferences or { };
in
{
  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      systemd.enable = cfg.enableSystemd;
      package = cfg.package;
      settings = {
        gtk-titlebar = cfg.gtkTitlebar;
        font-size = cfg.fontSize;
        font-family = prefs.terminalFont or null;
        window-width = cfg.windowWidth;
        window-height = cfg.windowHeight;
        theme = cfg.theme;
        keybind = cfg.keybindings ++ cfg.additionalKeybindings;
      } // cfg.extraSettings;
      clearDefaultKeybinds = cfg.clearDefaultKeybinds;
      themes = cfg.customThemes;
    };
  };
}
