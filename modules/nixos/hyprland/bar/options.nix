{ lib, ... }:
{
  options.my.desktop.hyprland.bar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable waybar status bar with Hyprland workspace integration.";
    };
    style = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        #custom-bar { background: red; }
      '';
      description = "Extra CSS injected into waybar's style.css on top of the default theme.";
    };
    position = lib.mkOption {
      type = lib.types.enum [ "top" "bottom" ];
      default = "top";
      description = "Waybar position on screen.";
    };
    height = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Waybar height in pixels.";
    };
  };
}
