{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  lockCfg = cfg.lockscreen;

  lockPkg = if lockCfg.useHyprlock then pkgs.hyprlock else lockCfg.package;
in
{
  config = lib.mkIf (cfg.enable && lockCfg.enable) {
    # Keep the option honest: `useHyprlock`'s description promises it sets the
    # package to hyprlock, and both the SUPER+L bind (core/config.nix) and
    # hypridle's lock_cmd derive the binary from this option. Without this the
    # option stayed swaylock and those two kept launching swaylock.
    my.desktop.hyprland.lockscreen.package =
      lib.mkIf lockCfg.useHyprlock (lib.mkDefault pkgs.hyprlock);

    environment.systemPackages = [ lockPkg ];

    # The swaylock/hyprlock config files are written by ./theme.nix (all colour
    # code lives there).

    programs.hyprlock = lib.mkIf lockCfg.useHyprlock {
      enable = true;
      package = pkgs.hyprlock;
    };
  };
}
