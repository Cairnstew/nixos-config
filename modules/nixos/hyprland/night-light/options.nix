{ lib, ... }:
{
  options.my.desktop.hyprland.nightLight = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hyprsunset blue-light filter with toggle keybind (SUPER+SHIFT+N).";
    };
    temperature = lib.mkOption {
      type = lib.types.int;
      default = 3500;
      example = 4500;
      description = "Color temperature in Kelvin. Lower = warmer. Default 3500K.";
    };
  };
}
