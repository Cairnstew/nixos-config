{ config, lib, ... }: {
  # Expected layout when installing NixOS on a disk with existing Windows:
  #   sdb1: ESP      (vfat, ~100M) — Windows EFI boot  (LABEL="EFI")
  #   sdb2: MSR      (16M)          — Microsoft Reserved
  #   sdb3: Windows  (NTFS, 80G)    — C: drive         (LABEL="Windows")
  #   sdb4: NixOS    (ext4, rest)   — NixOS root       (LABEL="nixos")
  #
  # This file provides disko.devices.disk.main ONLY when dualBoot is NOT
  # enabled. When my.disko.dualBoot.enable = true, the disko module at
  # modules/nixos/disko/config.nix handles partitioning instead.
  # The two-definition conflict caused the bug fixed by GOTCHAS entry
  # "disk-config.nix unconditionally overrides disko module".
  disko.devices.disk.main = lib.mkIf (!config.my.disko.dualBoot.enable) {
    type = "disk";
    device = lib.mkDefault "/dev/sdb";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        msr = {
          size = "16M";
          type = "E3C9E316-31B4-4298-89FA-94C9F823F8A5";
        };
        windows = {
          size = "80G";
          type = "0700";
          label = "Windows";
        };
        nixos = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
