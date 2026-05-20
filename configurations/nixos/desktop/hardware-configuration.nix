# =============================================================================
# Desktop Hardware Configuration (AMD-based)
# =============================================================================
# Physical Machine: AMD-based desktop PC with dual-boot support
#   - CPU: AMD (kvm-amd kernel module)
#   - GPU: AMD (Mesa drivers - configured in default.nix via gpu.mesa)
#   - Storage: NVMe SSD or SATA drives
#
# IMPORTANT: This is a TEMPLATE with placeholder values.
#
# Installation Options:
# 1. Run nixos-generate-config on the target machine:
#      nixos-generate-config --root /mnt
#    Then copy /mnt/etc/nixos/hardware-configuration.nix to this file.
#
# 2. Use nixos-anywhere (recommended for remote installs):
#      nix run github:nix-community/nixos-anywhere -- \
#        --flake .#desktop \
#        --target-host root@<target-ip> \
#        --disko-mode disko
#
# Filesystem Layout (UPDATE THESE FOR YOUR SYSTEM):
#   - /boot : vfat (EFI) on ESP partition - shared with Windows
#   - /     : ext4 on NixOS partition
#
# After installation, Windows will be installed to the Windows partition
# automatically on first boot via the windows-installer service.
# =============================================================================

{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # AMD CPU virtualization support
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # Filesystems are configured by disko - these are defaults that can be overridden
  # Disko generates: /dev/disk/by-partlabel/disk-main-nixos and disk-main-ESP
  # Use lib.mkDefault so disko configuration takes precedence

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-partlabel/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Enable AMD CPU microcode updates
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # AMD GPU support is handled via gpu.mesa.enable in default.nix
  # This provides Mesa drivers which support AMD Radeon GPUs

  # Bootloader is configured by disko module
  # GRUB is set up to chainload Windows from the ESP
}
