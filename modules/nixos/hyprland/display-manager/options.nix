{ lib, pkgs, ... }:
let
  inherit (lib) types;
in
{
  options.my.desktop.hyprland.displayManager = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable display manager (greetd or SDDM).";
    };

    greeter = lib.mkOption {
      type = types.enum [ "greetd" "sddm" ];
      default = "greetd";
      description = "Which display manager to use: greetd (TTY-based) or sddm (graphical with backgrounds).";
    };

    sessionCommand = lib.mkOption {
      type = types.str;
      default = "start-hyprland";
      description = "Session command passed to the greeter (for greetd).";
    };

    greeterPackage = lib.mkOption {
      type = types.package;
      default = pkgs.tuigreet;
      defaultText = lib.literalExpression "pkgs.tuigreet";
      description = "Greeter package for greetd (e.g., tuigreet, gtkgreet).";
    };

    extraGreetdArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ "--time" "--remember" ];
      example = [ "--time" "--remember" "--sessions" "/etc/nixos/sessions" ];
      description = "Extra CLI arguments for the greetd greeter command.";
    };

    sddm = {
      theme = lib.mkOption {
        type = types.package;
        default = pkgs.catppuccin-sddm;
        defaultText = lib.literalExpression "pkgs.catppuccin-sddm";
        description = "SDDM theme package.";
      };

      themeName = lib.mkOption {
        type = types.str;
        default = "catppuccin-mocha-mauve";
        description = "Theme directory name inside the package's share/sddm/themes/.";
      };

      background = lib.mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Background image for the SDDM login screen. Uses theme default if null.";
      };

      numlock = lib.mkOption {
        type = types.bool;
        default = true;
        description = "Enable numlock at login.";
      };

      enableHidpi = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Enable automatic HiDPI mode for SDDM.";
      };
    };
  };
}
