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
        keybind = cfg.keybindings ++ cfg.additionalKeybindings;
      } // lib.optionalAttrs (cfg.theme != null) { theme = cfg.theme; }
      // cfg.extraSettings;
      clearDefaultKeybinds = cfg.clearDefaultKeybinds;
      themes = lib.mkDefault cfg.customThemes;
    };
  };
}
