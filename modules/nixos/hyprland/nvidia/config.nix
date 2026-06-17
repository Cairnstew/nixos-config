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
  };
}
