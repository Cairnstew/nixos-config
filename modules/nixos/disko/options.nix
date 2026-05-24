{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.disko.dualBoot = {
    enable = mkEnableOption "dual-boot partition layout with NixOS and Windows";

    disk = mkOption {
      type = types.str;
      default = "/dev/nvme0n1";
      description = ''
        The disk device to partition for dual-boot.
        Default is /dev/nvme0n1 for NVMe SSDs.
        For SATA drives, use /dev/sda or similar.
      '';
    };

    espSizeGB = mkOption {
      type = types.int;
      default = 1;
      description = ''
        Size of the EFI System Partition in gigabytes.
        Shared between NixOS and Windows.
      '';
    };

    windowsSizeGB = mkOption {
      type = types.int;
      default = 150;
      description = ''
        Size of the Windows partition in gigabytes.
        Default 150GB should be sufficient for Windows 11 + applications.
      '';
    };

    nixosSizeGB = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        Size of the NixOS partition in gigabytes.
        Null means use all remaining space after ESP and Windows partitions.
        Set to a specific value to reserve space for additional partitions.
      '';
    };
  };
}
