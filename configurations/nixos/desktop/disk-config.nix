{ config, lib, ... }: {
  # Expected layout on /dev/sdb (existing, must not be modified):
  #   sdb1: ESP      (vfat) — Windows EFI boot, mounted at /boot
  #   sdb2: MSR      (16M)  — Microsoft Reserved, ignored
  #   sdb3: Windows  (NTFS) — C: drive, ignored
  #   sdb4: NixOS    (ext4) — NixOS root, formatted and mounted at /
  #
  # disko.devices.disk is NOT used here — declaring a disk triggers sgdisk
  # which wipes the partition table. Instead we use disko.devices.nodev to
  # target sdb1 and sdb4 directly as block devices with no partitioning step.
  #
  # Deploy with --disko-mode format (default for this host via auto-detection).
  # This file is only active when my.disko.dualBoot.enable = false.

  disko.devices = lib.mkIf (!config.my.disko.dualBoot.enable) {
    nodev = {
      "/" = {
        fsType = "ext4";
        device = "/dev/sdb4";
      };
      "/boot" = {
        fsType = "vfat";
        device = "/dev/sdb1";
        mountOptions = [ "umask=0077" ];
      };
    };
  };
}
