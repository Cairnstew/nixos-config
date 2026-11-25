{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  nvCfg = cfg.nvidia;
in
{
  config = lib.mkIf (cfg.enable && nvCfg.enable) {
    hardware.nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = false;
      nvidiaSettings = true;
    };
    boot.kernelParams = [ "nvidia-drm.modeset=1" ];

    # Exported by settings/config.nix through hl.env().
    my.desktop.hyprland.settings.env = {
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      WLR_NO_HARDWARE_CURSORS = "1";
    };
  };
}
