# configurations/nixos/desktop/disk-config.nix
#
# Targets existing partitions on /dev/sdb directly.
# No disko.devices.disk — avoids sgdisk/partition table changes.
#
# Deploy with:
#   nix run .#deploy-desktop -- nixos@<ip> --disko-mode mount
#
# Partition layout assumed to already exist:
#   sdb1: ESP   (vfat)  — shared Windows/NixOS EFI
#   sdb2: MSR   (16M)   — Microsoft Reserved, ignored
#   sdb3: Windows (NTFS) — untouched
#   sdb4: NixOS (ext4)  — NixOS root (will be formatted on first deploy)
{ ... }: {
  disko.devices.nodev = {
    "/" = {
      fsType = "ext4";
      device = "/dev/sda4";
    };
    "/boot" = {
      fsType = "vfat";
      device = "/dev/sda1";
      mountOptions = [ "umask=0077" ];
    };
  };
}
