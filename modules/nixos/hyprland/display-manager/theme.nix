# SDDM theming — aligns the login screen with the active scheme.
#
# SDDM's colours live inside its theme package, so this module cannot restyle
# the login screen directly. What it *can* derive from the palette is which
# Catppuccin flavour the theme is built for: `pkgs.catppuccin-sddm` is a
# `flavor`/`accent`-parameterised derivation, so the login screen follows
# `theming.scheme` for every Catppuccin scheme in the catalog. Non-Catppuccin
# schemes fall back to the previous mocha/mauve pair, since no matching theme
# package exists. The cursor theme is a stock GTK theme, not a colour.
{ config, lib, pkgs, ... }:

let
  cfg = config.my.desktop.hyprland;
  dmCfg = cfg.displayManager;
  themeLib = import ../../../../lib/theme.nix { inherit lib; };
  t = dmCfg.theme;
  p = t.palette;

  # Only Catppuccin has a themed SDDM package to select from.
  isCatppuccin = t.enable && p.family == "catppuccin";
  flavor = if isCatppuccin then p.variant else "mocha";
  accent = if isCatppuccin then t.accent else "mauve";

  sddmTheme =
    if isCatppuccin then
      pkgs.catppuccin-sddm.override { inherit flavor accent; }
    else
      pkgs.catppuccin-sddm;
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.hyprland.displayManager = {
    theme = themeLib.mkAppTheme {
      base = config.my.theming.colors;
      extraOptions =
        { config }:
        {
          accent = lib.mkOption {
            type = lib.types.str;
            default = "mauve";
            description = ''
              Catppuccin accent colour used to build the SDDM theme (mauve,
              blue, green, peach, …). Only affects Catppuccin schemes.
            '';
          };

          cursorTheme = lib.mkOption {
            type = lib.types.str;
            default = "Adwaita";
            description = "SDDM cursor theme name (stock GTK theme; not palette-derived).";
          };
        };
    };

    sddm.theme = lib.mkOption {
      type = lib.types.package;
      default = sddmTheme;
      defaultText = lib.literalExpression "pkgs.catppuccin-sddm (flavour from the active scheme)";
      description = "SDDM theme package.";
    };

    sddm.themeName = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-${flavor}-${accent}";
      defaultText = lib.literalExpression ''"catppuccin-<flavour>-<accent>" from the active scheme'';
      description = "Theme directory name inside the package's share/sddm/themes/.";
    };
  };
}
