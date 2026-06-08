{ lib, ... }: {
  # Expected layout when installing NixOS on a disk with existing Windows:
  #   sda1: ESP      (vfat, ~100M) — Windows EFI boot
  #   sda2: MSR      (16M)          — Microsoft Reserved
  #   sda3: Windows  (NTFS, 80G)    — C: drive
  #   sda4: NixOS    (ext4, rest)   — created in free space before first deploy
  #
  # Imported by default.nix. Provides disko.devices.disk.main for
  # nixos-anywhere + disko to discover the disk layout and mount
  # existing partitions (useExisting mode with --disko-mode mount).
  #
  # Usage with nixos-anywhere:
  #   First install (useExisting): nix run .#deploy -- desktop --addr nixos@nixos -- --disko-mode mount
  #   Fresh install (full disk):   nix run .#deploy -- desktop --addr nixos@nixos
  #   Reinstall (no tty):          nix run .#deploy-with-keys -- desktop --addr root@<IP>
  #   VM test:                     nix run .#deploy-test desktop
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
