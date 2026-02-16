{ flake, config, lib, pkgs, ... }:

let
  cfg = config.hardwareProfiles.gpu.nvidia;
in
{
  imports = [
    flake.self.nixosModules.graphics
    flake.self.nixosModules.xserver
  ];


  options.hardwareProfiles.gpu.nvidia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NVIDIA proprietary drivers.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.nvidiaPackages.stable;
      description = "The NVIDIA driver package to use.";
    };

    modesetting = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable modesetting for NVIDIA drivers.";
    };

    powerManagement = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable power management for NVIDIA drivers.";
    };

    finegrainedPowerManagement = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fine-grained power management for multi-GPU setups.";
    };

      open = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use the open NVIDIA driver (not nouveau).";
      };

      toolkit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable NVIDIA Container Toolkit for GPU acceleration in containers.";
      };

      blasklistNouveau = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Blacklist the nouveau kernel module to prevent conflicts with NVIDIA drivers.";
      };
  };

  config = lib.mkIf cfg.enable {
    hardware.nvidia = {
      package = cfg.package;
      modesetting.enable = cfg.modesetting;
      powerManagement.enable = cfg.powerManagement;
      powerManagement.finegrained = cfg.finegrainedPowerManagement;
      open = cfg.open;
    };

    boot.blacklistedKernelModules = lib.mkIf cfg.blasklistNouveau [ "nouveau" ];

    hardware.nvidia-container-toolkit.enable = cfg.toolkit;

    systemModules.graphics.enable = true;

    systemModules.xserver.enable = true;
    systemModules.xserver.videoDriver = [ "nvidia" ];

  };
}
