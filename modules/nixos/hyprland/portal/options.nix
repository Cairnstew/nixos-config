{ lib, ... }:
{
  options.my.desktop.hyprland.portal = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable xdg-desktop-portal-hyprland for Wayland portal support (file picker, screen sharing).";
    };
  };
}
