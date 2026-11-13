# GTK theming for the Hyprland desktop (GTK3 apps: thunar, nm-applet, waybar…).
#
# GTK3 has no declarative per-colour hook without shipping a whole theme, so
# this module aligns what *can* be aligned:
#
#   * dark/light preference follows the palette polarity
#   * theme/icon names are picked for that polarity
#
# When stylix is enabled it owns GTK (it generates a real palette-matched
# theme), so the theme/icon names are left out of the file and only the font
# and cursor geometry are written.
{ config, lib, ... }:

let
  cfg = config.my.desktop.hyprland;
  utilCfg = cfg.utilities;
  themeLib = import ../../../../lib/theme.nix { inherit lib; };
  t = utilCfg.theme;
  p = t.palette;

  stylixOwnsGtk = config.stylix.enable or false;

  # `Adwaita-dark` is the only stock GTK3 dark theme; there is no palette
  # equivalent in nixpkgs, so polarity is the honest mapping.
  gtkTheme = if p.polarity == "dark" then "Adwaita-dark" else "Adwaita";

  generated = ''
    [Settings]
    gtk-application-prefer-dark-theme=${if p.polarity == "dark" then "true" else "false"}
    gtk-cursor-theme-name=${t.cursorTheme}
    gtk-cursor-theme-size=${toString t.cursorSize}
    gtk-font-name=${t.fontName} ${toString t.fontSize}
  '' + lib.optionalString (!stylixOwnsGtk) ''
    gtk-icon-theme-name=${t.iconTheme}
    gtk-theme-name=${gtkTheme}
  '';
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.hyprland.utilities.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        cursorTheme = lib.mkOption {
          type = lib.types.str;
          default = "Adwaita";
          description = "Stock cursor theme name (no palette-derived cursor theme ships with nixpkgs).";
        };

        cursorSize = lib.mkOption {
          type = lib.types.int;
          default = 24;
          description = "Cursor size in pixels.";
        };

        iconTheme = lib.mkOption {
          type = lib.types.str;
          default = "Adwaita";
          description = "GTK icon theme name. Ignored when stylix owns GTK.";
        };

        fontName = lib.mkOption {
          type = lib.types.str;
          default = "Noto Sans";
          description = "GTK UI font family.";
        };

        fontSize = lib.mkOption {
          type = lib.types.int;
          default = 11;
          description = "GTK UI font size in points.";
        };

        settings = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          default = if config.enable then generated else "";
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = "The generated `/etc/xdg/gtk-3.0/settings.ini`.";
        };
      };
  };

  config = lib.mkIf (cfg.enable && utilCfg.enable && t.enable) {
    environment.etc."xdg/gtk-3.0/settings.ini".text = t.settings;
  };
}
