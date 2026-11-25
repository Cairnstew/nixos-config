# Hyprland appearance theming — palette-derived decoration defaults.
#
# The colour options themselves live in ../settings/spec.nix (one option per
# Hyprland setting). This file only supplies repo defaults for the three
# colours the palette owns, via lib.mkDefault so a host can still override
# them with a plain assignment:
#
#   general.col.active_border    accent → accentAlt diagonal gradient
#   general.col.inactive_border  palette surface
#   decoration.shadow.color      palette background at 80% alpha
{ config, lib, ... }:

let
  cfg = config.my.desktop.hyprland;
  appCfg = cfg.appearance;
  themeLib = import ../../../../lib/theme.nix { inherit lib; };
  t = appCfg.theme;
  color = themeLib.color;
  rgba = c: color.toCssRgba c;
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.hyprland.appearance.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
  };

  config = lib.mkIf (cfg.enable && appCfg.enable && t.enable) {
    my.desktop.hyprland.settings = {
      general.col.active_border = lib.mkDefault {
        colors = [ (rgba t.palette.accent) (rgba t.palette.accentAlt) ];
        angle = 45;
      };
      general.col.inactive_border = lib.mkDefault (rgba t.palette.backgroundElement);
      decoration.shadow.color = lib.mkDefault (rgba (color.alpha t.palette.background 0.8));
    };
  };
}
