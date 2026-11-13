# Hyprland appearance theming — the decoration shadow colour.
#
# The only colour in this module is the shadow, and it was a hardcoded
# `rgba(1a1a2ecc)`. It now defaults to the palette background at 80% alpha.
# The option itself stays a plain, overridable option: a host that wants a
# fixed shadow just assigns it (no `mkForce` needed).
{ config, lib, ... }:

let
  cfg = config.my.desktop.hyprland;
  appCfg = cfg.appearance;
  themeLib = import ../../../../lib/theme.nix { inherit lib; };
  t = appCfg.theme;
  color = themeLib.color;
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.hyprland.appearance = {
    theme = themeLib.mkAppTheme {
      base = config.my.theming.colors;
    };

    shadow.color = lib.mkOption {
      type = lib.types.str;
      default =
        if t.enable then
          color.toCssRgba (color.alpha t.palette.background 0.8)
        else
        # Pre-theming value, so opting out changes nothing.
          "rgba(1a1a2ecc)";
      example = "rgba(000000aa)";
      description = "Shadow color in RGBA format. Defaults to the palette background at 80% alpha.";
    };
  };
}
