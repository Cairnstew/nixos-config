{ config, lib, ... }: {
  # Expected layout on /dev/sdb:
  #   sdb1: ESP      (vfat, ~100M) — Windows EFI boot  (LABEL="EFI")
  #   sdb2: MSR      (16M)          — Microsoft Reserved
  #   sdb3: Windows  (NTFS, 80G)    — C: drive         (LABEL="Windows")
  #   sdb4: NixOS    (ext4, rest)   — NixOS root       (LABEL="nixos")
  #
  # sdb1/2/3 are existing partitions that must never be created or formatted.
  # They are declared with content = null so disko skips them during
  # format/mount phases. Only sdb4 (NixOS root) has a real content block.
  #
  # Deploy with --disko-mode format so the partition table is not recreated:
  #   nix run .#deploy-desktop -- nixos@nixos
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
          # Existing ESP — must NOT be created or formatted.
          # Mounted via fileSystems."/boot" when dualBoot is enabled.
          content = null;
        };
        msr = {
          size = "16M";
          type = "E3C9E316-31B4-4298-89FA-94C9F823F8A5";
          content = null;
        };
        windows = {
          size = "80G";
          type = "0700";
          label = "Windows";
          content = null;
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
