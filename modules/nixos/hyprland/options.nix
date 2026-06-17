{ lib, pkgs, flake, ... }:
{
  options.my.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland Wayland compositor desktop environment";

    user = lib.mkOption {
      type = lib.types.str;
      default = flake.config.me.username;
      example = "alice";
      description = "Primary user that will run the Hyprland session.";
    };


    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional packages to install alongside the desktop.";
    };

    terminal = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ghostty;
      defaultText = lib.literalExpression "pkgs.ghostty";
      description = "Default terminal emulator package (used for the SUPER+Return keybind).";
    };

    useMonitors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Use my.monitors to generate hyprland monitor lines instead of the
        flat string list in the old desktop.hyprland.monitors option.
      '';
    };
  };
}
