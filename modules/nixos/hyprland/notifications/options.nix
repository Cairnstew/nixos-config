{ lib, ... }:
{
  options.my.desktop.hyprland.notifications = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable mako notification daemon.";
    };
    position = lib.mkOption {
      type = lib.types.enum [ "top-right" "top-left" "bottom-right" "bottom-left" ];
      default = "top-right";
      description = "Notification position on screen.";
    };
    defaultTimeout = lib.mkOption {
      type = lib.types.int;
      default = 5000;
      description = "Default notification timeout in milliseconds.";
    };
    width = lib.mkOption {
      type = lib.types.int;
      default = 380;
      description = "Notification popup width in pixels.";
    };
  };
}
