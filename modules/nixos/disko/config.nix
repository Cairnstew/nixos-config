{ config, lib, ... }:
let
  cfg = config.my.disko.dualBoot;
  inherit (lib) mkIf mkDefault;
  isExisting = cfg.mode == "useExisting";
  isFresh = cfg.mode == "fresh";
in
mkIf cfg.enable {

  # ── fresh mode: disko creates everything ──────────────────
  # Layout: ESP → MSR → Windows → NixOS → [reserved free space]
  # Windows gets installed to partition 3 (after ESP + MSR).
  # NixOS before Windows keeps it safe from recovery partition theft.
  disko.devices.disk.main = mkIf isFresh {
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
        msr = {
          size = "${toString cfg.msrSizeMB}M";
          type = "E3C9E316-31B4-4298-89FA-94C9F823F8A5";
        };
        windows = {
          size = "${toString cfg.windowsSizeGB}G";
          type = "0700";
          label = "Windows";
        };
        nixos = {
          size =
            if cfg.nixosSizeGB != null then "${toString cfg.nixosSizeGB}G"
            else "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  # reservedSizeGB > 0 requires explicit nixosSizeGB
  assertions = [{
    assertion = !(cfg.enable && isFresh && cfg.reservedSizeGB > 0 && cfg.nixosSizeGB == null);
    message = "my.disko.dualBoot.nixosSizeGB is required when reservedSizeGB > 0.";
  }];

  # ── useExisting mode: adopt existing partitions ───────────
  # Disks already exist — just declare filesystems so nixos-install
  # knows what to mount. Format NixOS root manually before install:
  #   mkfs.ext4 /dev/nvme0n1p5

  fileSystems."/" = mkIf isExisting {
    device = mkDefault cfg.nixosPartition;
    fsType = "ext4";
  };

  fileSystems."/boot" = mkIf isExisting {
    device = mkDefault (
      if cfg.espPartition != null
      then cfg.espPartition
      else "/dev/disk/by-parttype-uuid/ESP"
    );
    fsType = "vfat";
    options = [ "umask=0077" ];
  };

  # ── Bootloader ────────────────────────────────────────────
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = mkDefault true;
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
