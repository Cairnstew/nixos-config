{ config, lib, pkgs, modulesPath, ... }: {
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  # Oracle Cloud A1 instances are paravirtualized — virtio for block/storage,
  # plus sd_mod/nvme/usb to cover the attach paths OCI uses.
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" "virtio_scsi" "nvme" "sd_mod" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = lib.mkDefault "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = lib.mkDefault "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
  swapDevices = [ ];
  networking.useDHCP = lib.mkDefault true;
  # ARM64 — Oracle Always Free Ampere A1 (set explicitly in default.nix too)
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}