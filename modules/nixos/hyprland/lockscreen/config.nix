{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  lockCfg = cfg.lockscreen;

  lockPkg = if lockCfg.useHyprlock then pkgs.hyprlock else lockCfg.package;
in
{
  config = lib.mkIf (cfg.enable && lockCfg.enable) {
    environment.systemPackages = [ lockPkg ];

    # The swaylock/hyprlock config files are written by ./theme.nix (all colour
    # code lives there).

    programs.hyprlock = lib.mkIf lockCfg.useHyprlock {
      enable = true;
      package = pkgs.hyprlock;
    };
  };
}
