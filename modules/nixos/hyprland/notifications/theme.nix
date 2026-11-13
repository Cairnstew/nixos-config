# mako theming — the notification daemon config, generated from the palette.
#
# mako is configured with a flat `key=value` file, so the colours are plain
# interpolations (no CSS/format layer to map onto).
{ config, lib, ... }:

let
  cfg = config.my.desktop.hyprland;
  notifCfg = cfg.notifications;
  themeLib = import ../../../../lib/theme.nix { inherit lib; };
  t = notifCfg.theme;
  p = t.palette;

  generated = ''
    background-color=${p.background}
    text-color=${p.foreground}
    border-color=${p.accent}
    border-radius=8
    border-size=2
    padding=10
    margin=8
    font=JetBrainsMono Nerd Font 11
    width=${toString notifCfg.width}
    height=120
    default-timeout=${toString notifCfg.defaultTimeout}
    [urgency=critical]
    border-color=${p.error}
    default-timeout=0
  '';
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.hyprland.notifications.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        settings = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          default = if config.enable then generated else "";
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = "The generated mako config file.";
        };
      };
  };

  config = lib.mkIf (cfg.enable && notifCfg.enable && t.enable) {
    environment.etc."xdg/mako/config".text = t.settings;
  };
}
