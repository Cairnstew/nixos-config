{ config, lib, ... }:
let
  cfg = config.my.disko.dualBoot;
  inherit (lib) mkIf mkDefault;
in
mkIf cfg.enable {
  disko.devices = {
    disk.main = {
      type = "disk";
      device = mkDefault cfg.disk;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "${toString cfg.espSizeGB}G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          windows = {
            size = "${toString cfg.windowsSizeGB}G";
            type = "0700";
            label = "Windows";
          };

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

  boot.loader.grub.useOSProber = mkDefault true;

  boot.loader.grub.extraEntries = mkDefault ''
    menuentry "Windows 11" {
      insmod part_gpt
      insmod fat
      insmod chain
      search --no-floppy --label --set=root ESP
      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
  '';
}
