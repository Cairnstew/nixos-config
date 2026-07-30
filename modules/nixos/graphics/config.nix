{ config, lib, pkgs, flake, ... }:
let
  inherit (lib) mkIf mkMerge;
  cfg = config.my.hardware;
  nvidia = cfg.gpu.nvidia;
  amd = cfg.gpu.amd;
  mesa = cfg.gpu.mesa;
  vulkan = cfg.vulkan;
in
{
  config = mkMerge [
    (mkIf cfg.graphics.enable {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
      hardware.acpilight.enable = true;
      users.users.${flake.config.me.username} = {
        extraGroups = [ "video" ];
      };
    })

    (mkIf cfg.xserver.enable {
      services.xserver.enable = true;
      services.xserver.videoDrivers = mkIf
        (
          cfg.xserver.videoDriver != [ "auto" ]
        )
        cfg.xserver.videoDriver;
    })

    (mkIf nvidia.enable {
      hardware.nvidia = {
        package = nvidia.package;
        modesetting.enable = nvidia.modesetting;
        powerManagement.enable = nvidia.powerManagement;
        powerManagement.finegrained = nvidia.finegrainedPowerManagement;
        open = nvidia.open;
      };

      boot.blacklistedKernelModules =
        mkIf nvidia.blacklistNouveau [ "nouveau" ];

      hardware.nvidia-container-toolkit.enable = nvidia.toolkit;
      hardware.nvidia-container-toolkit.suppressNvidiaDriverAssertion =
        mkIf nvidia.headless true;

      services.xserver.videoDrivers = [ "nvidia" ];

      # Enable graphics + X server for non-headless NVIDIA
      hardware.graphics.enable = mkIf (!nvidia.headless) true;
      services.xserver.enable = mkIf (!nvidia.headless) true;
    })

    (mkIf (nvidia.enable && nvidia.cuda) {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.config.cuda.acceptLicense = true;
      nixpkgs.config.cudaSupport = true;

      nixpkgs.overlays = [
        (final: prev: {
          cudaPackages = prev.cudaPackages.overrideScope (cfinal: cprev: {
            cuda_compat = prev.emptyDirectory;
          });
        })
        # Break the dep chain: nvshmem → openmpi → ucc → nccl
        # OpenMPI doesn't need UCC (Unified Communication Collection) for basic
        # GPU communication, and UCC requires building raw NCCL from source (~hours).
        # The Python nvidia-nccl-cu13 wheel provides NCCL at the Python level.
        (final: prev: {
          openmpi = prev.openmpi.overrideAttrs (oa: {
            buildInputs = builtins.filter (x: x != prev.ucc) (oa.buildInputs or [ ]);
          });
        })
      ];
    })

    (mkIf amd.enable {
      services.xserver.videoDrivers = [ "amdgpu" ];
      hardware.graphics.enable = true;
    })

    (mkIf mesa.enable {
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    })

    (mkIf vulkan.enable {
      hardware.graphics.extraPackages = with pkgs; [
        vulkan-loader
        vulkan-validation-layers
      ];

      hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
        vulkan-loader
      ];

      hardware.graphics.enable = true;
    })
  ];
}
