{ config, lib, ... }:
let
  cfg = config.my.desktop.hyprland;
  appCfg = cfg.appearance;
in
{
  config = lib.mkIf (cfg.enable && appCfg.enable) {
    environment.etc."xdg/hypr/hyprland.lua".text = lib.mkAfter ''

      -- ── Appearance ────────────────────────────────────────────────────────
      hl.config({
        decoration = {
          rounding = ${toString appCfg.rounding},
          ${lib.optionalString appCfg.windowOpacity.enable "active_opacity = ${toString appCfg.windowOpacity.focused},"}
          ${lib.optionalString appCfg.windowOpacity.enable "inactive_opacity = ${toString appCfg.windowOpacity.unfocused},"}
          ${lib.optionalString appCfg.blur.enable ''
          blur = {
            enabled = true,
            size = ${toString appCfg.blur.size},
            passes = ${toString appCfg.blur.passes},
          },
          ''}
          ${lib.optionalString appCfg.shadow.enable ''
          shadow = {
            enabled = true,
            range = ${toString appCfg.shadow.range},
            render_power = ${toString appCfg.shadow.renderPower},
            color = "${appCfg.shadow.color}",
          },
          ''}
        },
      })

      -- ── Window opacity overrides ──────────────────────────────────────────
      ${lib.concatStringsSep "\n" (builtins.map (o: ''hl.window_rule({ match = { class = "^(${o.class})$" }, opacity = "${toString o.focused} ${toString o.unfocused}" })'') appCfg.windowOpacity.overrides)}
    '';
  };
}
