{ lib, pkgs, ... }:
{
  options.my.desktop.hyprland.displayManager = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable greetd display manager with tuigreet TTY greeter.";
    };
    greeter = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tuigreet;
      defaultText = lib.literalExpression "pkgs.tuigreet";
      description = "Greeter package for greetd.";
    };
    sessionCommand = lib.mkOption {
      type = lib.types.str;
      default = "start-hyprland";
      description = "Session command passed to the greeter.";
    };
  };
}
