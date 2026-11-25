{ config, lib, ... }:
let
  cfg = config.my.desktop.hyprland;
  appCfg = cfg.appearance;
in
{
  config = lib.mkIf (cfg.enable && appCfg.enable) {
    environment.etc."xdg/hypr/hyprland.lua".text = lib.mkAfter ''

      -- ── Per-class opacity overrides ─────────────────────────────────────
      ${lib.concatStringsSep "\n" (builtins.map
        (o: ''hl.window_rule({ match = { class = "^(${o.class})$" }, opacity = "${toString o.focused} ${toString o.unfocused}" })'')
        appCfg.overrides)}
    '';
  };
}
