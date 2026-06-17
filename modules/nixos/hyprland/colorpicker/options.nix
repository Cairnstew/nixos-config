{ lib, ... }:
{
  options.my.desktop.hyprland.colorpicker = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hyprpicker color picker tool (SUPER+SHIFT+P). Copies hex color to clipboard.";
    };
  };
}
