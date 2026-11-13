# GNOME theming (Home-Manager side) — dconf + GTK settings from the palette.
#
# GNOME exposes no per-colour hook; what it does expose is enough to make a
# scheme change visible: the `prefer-dark`/`prefer-light` colour scheme, the
# screensaver accent, and the GTK theme/icon/cursor names. GNOME's shell theme
# itself is owned by `gnome-shell-extensions`/stylix, not by a colour file.
#
# When stylix is enabled it owns GTK and Qt (it generates a palette-matched
# theme), so this file applies nothing and only the `theme.palette` option
# remains for introspection.
{ config, lib, ... }:

let
  cfg = config.my.desktop.gnome;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
  p = t.palette;

  stylixOwnsGtk = config.stylix.enable or false;
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.gnome.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
  };

  config = lib.mkIf (cfg.enable && t.enable && !stylixOwnsGtk) {
    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = if p.polarity == "dark" then "prefer-dark" else "prefer-light";
        cursor-theme = cfg.cursorTheme;
        cursor-size = cfg.cursorSize;
        font-name = cfg.fontName;
        monospace-font-name = cfg.fontMonospace;
      };

      # Screensaver accent colours read the palette directly (they were the only
      # palette reads in home.nix).
      "org/gnome/desktop/screensaver" = {
        primary-color = p.accent;
        secondary-color = p.background;
      };
    };

    gtk = {
      enable = true;
      gtk3.extraConfig.gtk-application-prefer-dark-theme = p.polarity == "dark";
      iconTheme.name = cfg.iconTheme;
      theme.name = cfg.gtkTheme;
      cursorTheme = {
        name = cfg.cursorTheme;
        size = cfg.cursorSize;
      };
    };
  };
}
