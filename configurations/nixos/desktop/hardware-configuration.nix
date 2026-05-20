# =============================================================================
# Desktop Hardware Configuration (AMD-based)
# =============================================================================
# Physical Machine: AMD-based desktop PC
#   - CPU: AMD (kvm-amd kernel module)
#   - GPU: AMD (Mesa drivers - configured in default.nix via gpu.mesa)
#   - Storage: NVMe SSD or SATA drives
#
# IMPORTANT: This is a TEMPLATE with placeholder values.
# You MUST regenerate this file using:
#   nixos-generate-config --root /mnt
# Or update the UUIDs and device paths to match your actual hardware.
#
# Filesystem Layout (UPDATE THESE FOR YOUR SYSTEM):
#   - /     : ext4 on /dev/disk/by-uuid/YOUR-ROOT-UUID
#   - /boot : vfat (EFI) on /dev/disk/by-uuid/YOUR-BOOT-UUID
#
# After installation, copy the generated hardware-configuration.nix from
# /etc/nixos/hardware-configuration.nix to this file.
# =============================================================================

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # AMD CPU virtualization support
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # TODO: Replace with your actual root filesystem UUID
  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/PLACEHOLDER-ROOT-UUID";
      fsType = "ext4";
    };

  # TODO: Replace with your actual boot partition UUID
  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/PLACEHOLDER-BOOT-UUID";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  
  # Enable AMD CPU microcode updates
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  
  # AMD GPU support is handled via gpu.mesa.enable in default.nix
  # This provides Mesa drivers which support AMD Radeon GPUs
}
