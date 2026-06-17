{ lib, ... }:
{
  options.my.desktop.hyprland.wallpaper = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable hyprpaper wallpaper daemon.";
    };
    images = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      description = "List of wallpaper image paths to preload and set.";
    };
  };
}
