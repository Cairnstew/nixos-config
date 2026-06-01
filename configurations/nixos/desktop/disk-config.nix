{ lib, ... }: {
  # Expected layout when installing NixOS on a disk with existing Windows:
  #   sda1: ESP      (vfat, ~100M) — Windows EFI boot
  #   sda2: MSR      (16M)          — Microsoft Reserved
  #   sda3: Windows  (NTFS, 80G)    — C: drive
  #   sda4: NixOS    (ext4, rest)   — created in free space before first deploy
  #
  # This file is NOT imported by the NixOS config (the dual-boot module
  # handles disko.devices in fresh mode, and fileSystems in useExisting mode).
  # It exists here for nixos-anywhere's deploy.nix to detect that this host
  # uses nixos-anywhere, and for reference documentation of the layout.
  #
  # Usage with nixos-anywhere:
  #   Fresh install (full disk, no Windows): nix run .#deploy desktop root@<IP>
  #   Reinstall (Windows on sda1-3, mount existing):
  #     nix run .#deploy desktop root@<IP> -- --disko-mode mount
  #   VM test:
  #     nix run .#deploy-test desktop   # requires disko devices to be imported
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/sda";
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
