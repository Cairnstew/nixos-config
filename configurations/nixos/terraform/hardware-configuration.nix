{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # This provides standard modules for Amazon, Azure, Google, etc.
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  # Bootloader settings
  boot.initrd.availableKernelModules = [ "nvme" "pciehp" "xhci_pci" "virtio_pci" "virtio_scsi" "usbhid" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ]; # Use "kvm-amd" if your cloud provider uses AMD CPUs
  boot.extraModulePackages = [ ];

  # File system configuration
  # Usually, cloud images use "/" for everything. 
  # Note: You may need to change "label/nixos" to the actual device path if not using labels.
  fileSystems."/" =
    { device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
    };

  # Swap space (optional, but recommended for small RAM VMs)
  swapDevices = [ ];

  # Networking
  # Cloud providers usually handle DHCP for you
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}