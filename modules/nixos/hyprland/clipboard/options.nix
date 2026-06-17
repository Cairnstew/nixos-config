{ lib, ... }:
{
  options.my.desktop.hyprland.clipboard = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable wl-clipboard (wl-copy/wl-paste) and cliphist clipboard manager.";
    };
    history = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable cliphist clipboard history management.";
    };
  };
}
