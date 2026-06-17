{ lib, pkgs, ... }:
{
  options.my.desktop.hyprland.lockscreen = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable screen locker (SUPER+L).";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.swaylock;
      defaultText = lib.literalExpression "pkgs.swaylock";
      example = lib.literalExpression "pkgs.hyprlock";
      description = "Lock screen package (swaylock or hyprlock).";
    };
    useHyprlock = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use hyprlock instead of swaylock. Sets package to pkgs.hyprlock and generates hyprlock.conf.";
    };
  };
}
