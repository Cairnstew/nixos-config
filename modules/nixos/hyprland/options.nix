{ lib, ... }:
{
  options.my.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland Wayland compositor" // {
      default = true;
    };
  };
}
