# modules/nixos/disko/dual-boot.nix
# Dual-boot partition layout with NixOS and Windows
{ config, lib, flake, ... }:
let
  cfg = config.my.disko.dualBoot;
  inherit (lib) mkEnableOption mkOption types mkDefault;
in
{
  imports = [ flake.inputs.disko.nixosModules.default ];

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

  config = lib.mkIf cfg.enable {
    # Disko configuration
    disko.devices = {
      disk.main = {
        type = "disk";
        device = mkDefault cfg.disk;
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition (ESP) - shared between NixOS and Windows
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            # Windows partition - NTFS, will be formatted by Windows installer
            windows = {
              size = "${toString cfg.windowsSizeGB}G";
              type = "0700";
              label = "Windows";
              # No content - Windows installer will format this
            };

            # NixOS root partition
            nixos = {
              size = if cfg.nixosSizeGB == null then "100%" else "${toString cfg.nixosSizeGB}G";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };

    # Ensure bootloader can find Windows
    boot.loader.grub.useOSProber = mkDefault true;

    # Additional GRUB entry for Windows (fallback if os-prober doesn't work)
    boot.loader.grub.extraEntries = mkDefault ''
      menuentry "Windows 11" {
        insmod part_gpt
        insmod fat
        insmod chain
        search --no-floppy --label --set=root ESP
        chainloader /EFI/Microsoft/Boot/bootmgfw.efi
      }
    '';
  };
}
