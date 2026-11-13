# Monitoring theming — Grafana's default UI theme from the palette polarity.
#
# Grafana OSS exposes no custom-CSS hook, so the only honest mapping is
# dark/light: `users.default_theme` decides what every user sees before they
# pick a theme of their own. Dashboards and panels keep Grafana's own colours.
{ config, lib, ... }:

let
  cfg = config.my.services.monitoring;
  themeLib = import ../../../lib/theme.nix { inherit lib; };
  t = cfg.theme;
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.services.monitoring.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        grafanaTheme = lib.mkOption {
          type = lib.types.enum [
            "dark"
            "light"
            "system"
          ];
          default =
            if config.palette.polarity == "dark" then "dark" else "light";
          description = ''
            Grafana's `users.default_theme`. "system" would follow each
            viewer's OS, which cannot be known here, so the palette polarity is
            resolved to dark/light explicitly.
          '';
        };
      };
  };

  config = lib.mkIf (cfg.enable && cfg.grafana.enable && t.enable) {
    services.grafana.settings.users.default_theme = t.grafanaTheme;
  };
}
