# Screen-locker theming — swaylock and hyprlock configs from the palette.
#
# Both lockers take colours in their own syntax: swaylock wants hashless
# `rrggbb`, hyprlock wants `rgba(r, g, b, a)`. Only one of the two files is
# written, depending on `lockscreen.useHyprlock`.
{ config, lib, ... }:

let
  cfg = config.my.desktop.hyprland;
  lockCfg = cfg.lockscreen;
  themeLib = import ../../../../lib/theme.nix { inherit lib; };
  t = lockCfg.theme;
  p = t.palette;
  color = themeLib.color;

  # swaylock: bare hex, no "#".
  hex = color.toBase16;

  # hyprlock: rgba() with an explicit alpha.
  rgba = h: a: color.toCssRgba (color.alpha h a);

  swaylockConf = ''
    color=${hex p.background}
    ring-color=${hex p.accent}
    inside-color=${hex p.surface}
    text-color=${hex p.foreground}
    line-color=${hex p.accent}
    key-hl-color=${hex p.syntaxKeyword}
    bs-hl-color=${hex p.error}
    font=JetBrainsMono Nerd Font
    font-size=14
    indicator-radius=80
  '';

  hyprlockConf = ''
    background {
        monitor =
        color = ${rgba p.background 1.0}
    }

    input-field {
        monitor =
        size = 300, 50
        outline_thickness = 2
        dots_size = 0.33
        dots_spacing = 0.15
        dots_center = true
        outer_color = ${rgba p.accent 0.8}
        inner_color = ${rgba p.surface 1.0}
        font_color = ${rgba p.foreground 1.0}
        fade_on_empty = true
        placeholder_text = <i>Password...</i>
        hide_input = false
        position = 0, -80
        halign = center
        valign = center
    }
  '';
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.hyprland.lockscreen.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        swaylockConfig = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          default = if config.enable then swaylockConf else "";
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = "The generated `xdg/swaylock/config` (used when `useHyprlock = false`).";
        };

        hyprlockConfig = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          default = if config.enable then hyprlockConf else "";
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = "The generated `xdg/hypr/hyprlock.conf` (used when `useHyprlock = true`).";
        };
      };
  };

  config = lib.mkIf (cfg.enable && lockCfg.enable && t.enable) {
    environment.etc = lib.optionalAttrs (!lockCfg.useHyprlock)
      {
        "xdg/swaylock/config".text = t.swaylockConfig;
      } // lib.optionalAttrs lockCfg.useHyprlock {
      "xdg/hypr/hyprlock.conf".text = t.hyprlockConfig;
    };
  };
}
