{ lib, ... }:
{
  options.my.desktop.hyprland.nvidia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Nvidia-specific hardware configuration (modesetting, kernel params).
        Also sets Nvidia-specific environment variables in the Hyprland session
        (LIBVA_DRIVER_NAME, __GLX_VENDOR_LIBRARY_NAME, WLR_NO_HARDWARE_CURSORS).
      '';
    };
  };
}
