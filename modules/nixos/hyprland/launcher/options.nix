{ lib, pkgs, ... }:
{
  options.my.desktop.hyprland.launcher = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable wofi application launcher (SUPER+D).";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wofi;
      defaultText = lib.literalExpression "pkgs.wofi";
      description = "Application launcher package (wofi, rofi, etc.).";
    };
    args = lib.mkOption {
      type = lib.types.str;
      default = "--show drun";
      description = "Extra arguments passed to the launcher command.";
    };
  };
}
