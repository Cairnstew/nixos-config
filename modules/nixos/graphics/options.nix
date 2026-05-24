{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.hardware = {
    graphics = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable base graphics stack (OpenGL + 32-bit support).";
      };
    };

    xserver = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the X server with GPU support.";
      };

      videoDriver = mkOption {
        type = types.listOf types.str;
        default = [ "auto" ];
        description = "The Xorg video drivers to use. Use [\"auto\"] to auto-detect.";
      };
    };

    gpu = {
      nvidia = {
        enable = mkEnableOption "NVIDIA proprietary drivers";

        headless = mkOption {
          type = types.bool;
          default = false;
          description = "Enable NVIDIA drivers without any graphics/display stack (for CUDA, containers, etc).";
        };

        package = mkOption {
          type = types.package;
          default = config.boot.kernelPackages.nvidiaPackages.stable;
          description = "The NVIDIA driver package to use.";
        };

        modesetting = mkOption {
          type = types.bool;
          default = true;
          description = "Enable modesetting for NVIDIA drivers.";
        };

        powerManagement = mkOption {
          type = types.bool;
          default = true;
          description = "Enable power management for NVIDIA drivers.";
        };

        finegrainedPowerManagement = mkOption {
          type = types.bool;
          default = false;
          description = "Enable fine-grained power management for multi-GPU setups.";
        };

        open = mkOption {
          type = types.bool;
          default = false;
          description = "Use the open NVIDIA driver (not nouveau).";
        };

        toolkit = mkOption {
          type = types.bool;
          default = true;
          description = "Enable NVIDIA Container Toolkit for GPU acceleration in containers.";
        };

        blacklistNouveau = mkOption {
          type = types.bool;
          default = true;
          description = "Blacklist the nouveau kernel module to prevent conflicts with NVIDIA drivers.";
        };

        cuda = mkOption {
          type = types.bool;
          default = false;
          description = "Allow unfree CUDA packages (cuda_cccl, cuda_cudart, cuda_nvcc, libcublas, nvidia-settings, nvidia-x11).";
        };
      };

      amd = {
        enable = mkEnableOption "AMDGPU driver explicitly";
      };

      mesa = {
        enable = mkEnableOption "Mesa-based GPU drivers (Intel / AMD)";
      };
    };

    vulkan = {
      enable = mkEnableOption "Vulkan loader and validation layers";
    };
  };
}
