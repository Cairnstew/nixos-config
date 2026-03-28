{ flake, config, lib, pkgs, ... }:

let
  cfg    = config.systemModules;
  gfx    = cfg.graphics;
  xsrv   = cfg.xserver;
  nvidia = config.hardwareProfiles.gpu.nvidia;
  amd    = config.hardwareProfiles.gpu.amd;
  mesa   = config.hardwareProfiles.gpu.mesa;
  vulkan = config.hardwareProfiles.vulkan;
in
{
  # ────────────────────────────────────────────────────────────────
  # Options
  # ────────────────────────────────────────────────────────────────

  options = {

    # -- Base graphics stack -----------------------------------------
    systemModules.graphics.enable = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Enable base graphics stack (OpenGL + 32-bit support).";
    };

    # -- X server ----------------------------------------------------
    systemModules.xserver = {
      enable = lib.mkOption {
        type        = lib.types.bool;
        default     = false;
        description = "Enable the X server with GPU support.";
      };

      videoDriver = lib.mkOption {
        type        = lib.types.listOf lib.types.str;
        default     = [ "auto" ];
        description = "The Xorg video drivers to use. Use [\"auto\"] to auto-detect.";
      };
    };

    # -- GPU: NVIDIA -------------------------------------------------
    hardwareProfiles.gpu.nvidia = {
      enable = lib.mkOption {
        type        = lib.types.bool;
        default     = false;
        description = "Enable NVIDIA proprietary drivers.";
      };

      headless = lib.mkOption {
        type        = lib.types.bool;
        default     = false;
        description = "Enable NVIDIA drivers without any graphics/display stack (for CUDA, containers, etc).";
      };

      package = lib.mkOption {
        type        = lib.types.package;
        default     = config.boot.kernelPackages.nvidiaPackages.stable;
        description = "The NVIDIA driver package to use.";
      };

      modesetting = lib.mkOption {
        type        = lib.types.bool;
        default     = true;
        description = "Enable modesetting for NVIDIA drivers.";
      };

      powerManagement = lib.mkOption {
        type        = lib.types.bool;
        default     = true;
        description = "Enable power management for NVIDIA drivers.";
      };

      finegrainedPowerManagement = lib.mkOption {
        type        = lib.types.bool;
        default     = false;
        description = "Enable fine-grained power management for multi-GPU setups.";
      };

      open = lib.mkOption {
        type        = lib.types.bool;
        default     = false;
        description = "Use the open NVIDIA driver (not nouveau).";
      };

      toolkit = lib.mkOption {
        type        = lib.types.bool;
        default     = true;
        description = "Enable NVIDIA Container Toolkit for GPU acceleration in containers.";
      };

      blasklistNouveau = lib.mkOption {
        type        = lib.types.bool;
        default     = true;
        description = "Blacklist the nouveau kernel module to prevent conflicts with NVIDIA drivers.";
      };
      CUDABinaryCache = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Toggle for using dua binary cache to speed up build times.";
      };
    };

    # -- GPU: AMD ----------------------------------------------------
    hardwareProfiles.gpu.amd.enable = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Enable AMDGPU driver explicitly.";
    };

    # -- GPU: Mesa (Intel / AMD generic) ----------------------------
    hardwareProfiles.gpu.mesa.enable = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Enable Mesa-based GPU drivers (Intel / AMD).";
    };

    # -- Vulkan ------------------------------------------------------
    hardwareProfiles.vulkan.enable = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = "Enable Vulkan loader and validation layers.";
    };
  };

  # ────────────────────────────────────────────────────────────────
  # Config
  # ────────────────────────────────────────────────────────────────

  config = lib.mkMerge [

    # -- Base graphics stack -----------------------------------------
    (lib.mkIf gfx.enable {
      hardware.graphics = {
        enable     = true;
        enable32Bit = true;
      };
      programs.light.enable = true; # sets up udev rules
      users.users.${flake.config.me.username} = {
        extraGroups = [ "video" ];
      };
    })

    # -- X server ----------------------------------------------------
    (lib.mkIf xsrv.enable {
      services.xserver.enable = true;
      services.xserver.videoDrivers = lib.mkIf (
        xsrv.videoDriver != [ "auto" ]
      ) xsrv.videoDriver;
    })

    # -- GPU: NVIDIA -------------------------------------------------
    (lib.mkIf nvidia.enable {
      hardware.nvidia = {
        package                      = nvidia.package;
        modesetting.enable           = nvidia.modesetting;
        powerManagement.enable       = nvidia.powerManagement;
        powerManagement.finegrained  = nvidia.finegrainedPowerManagement;
        open                         = nvidia.open;
      };

      boot.blacklistedKernelModules = lib.mkIf nvidia.blasklistNouveau [ "nouveau" ];

      hardware.nvidia-container-toolkit.enable = nvidia.toolkit;
      hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion = lib.mkIf nvidia.headless true;

      #hardware.nvidia.datacenter.enable = lib.mkIf nvidia.headless true;

      systemModules.graphics.enable     = lib.mkIf (!nvidia.headless) true;
      systemModules.xserver.enable      = lib.mkIf (!nvidia.headless) true;
      systemModules.xserver.videoDriver = lib.mkIf (!nvidia.headless) [ "nvidia" ];
    })
    (lib.mkIf nvidia.CUDABinaryCache {
      nix.settings = {
        extra-substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
        ];
        extra-trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
        ];
      };
    })
    # -- GPU: AMD ----------------------------------------------------
    (lib.mkIf amd.enable {
      systemModules.xserver.videoDriver = [ "amdgpu" ];
      systemModules.graphics.enable     = true;
    })

    # -- GPU: Mesa ---------------------------------------------------
    (lib.mkIf mesa.enable {
      systemModules.graphics.enable = true;
    })

    # -- Vulkan ------------------------------------------------------
    (lib.mkIf vulkan.enable {
      hardware.graphics.extraPackages = with pkgs; [
        vulkan-loader
        vulkan-validation-layers
      ];

      hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
        vulkan-loader
      ];

      systemModules.graphics.enable = true;
    })

  ];
}
