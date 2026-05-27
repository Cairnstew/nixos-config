{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types mkIf;
in {
  options.my.disko.dualBoot = {
    enable = mkEnableOption "dual-boot with NixOS and Windows";

    mode = mkOption {
      type = types.enum [ "fresh" "useExisting" ];
      default = "useExisting";
      description = ''
        "fresh" — create all partitions (ESP + Windows + NixOS) from scratch.
          Requires {option} `windowsSizeGB` and optionally `nixosSizeGB`.
        "useExisting" — adopt existing Windows + ESP partitions, only manage
          the NixOS partition. Requires {option} `nixosPartition`.
      '';
    };

    disk = mkOption {
      type = types.str;
      default = "/dev/nvme0n1";
      description = "The disk device containing the NixOS root partition.";
    };

    # ── fresh-mode options ──────────────────────────────────
    espSizeGB = mkOption {
      type = types.int;
      default = 1;
      description = "Size of the EFI System Partition in GB (fresh mode only).";
    };

    windowsSizeGB = mkOption {
      type = types.int;
      default = 150;
      description = "Size of the Windows partition in GB (fresh mode only).";
    };

    nixosSizeGB = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        Size of the NixOS partition in GB (fresh mode).
        Null = remaining space after ESP + Windows.
      '';
    };

    # ── useExisting-mode options ────────────────────────────
    nixosPartition = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/dev/nvme0n1p5";
      description = ''
        Existing partition to use for NixOS. Required when
        {option}`mode` is "useExisting".
      '';
    };

    espPartition = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/dev/nvme0n1p1";
      description = ''
        Existing EFI System Partition. If unset in useExisting mode,
        the module auto-selects the first vfat partition on {option}`disk`.
      '';
    };

    # ── Detection metadata (set manually or via detect-dualboot) ─
    detection = {
      windowsPartition = mkOption {
        type = types.nullOr types.str;
        default = null;
        internal = true;
        description = "Detected Windows partition device path.";
      };
      windowsSize = mkOption {
        type = types.nullOr types.str;
        default = null;
        internal = true;
        description = "Detected Windows partition size (human-readable).";
      };
      windowsLabel = mkOption {
        type = types.nullOr types.str;
        default = null;
        internal = true;
        description = "Detected Windows partition label.";
      };
      espPartition = mkOption {
        type = types.nullOr types.str;
        default = null;
        internal = true;
        description = "Detected EFI System Partition device path.";
      };
      espLabel = mkOption {
        type = types.nullOr types.str;
        default = null;
        internal = true;
        description = "Detected EFI System Partition label.";
      };
      disk = mkOption {
        type = types.nullOr types.str;
        default = null;
        internal = true;
        description = "Disk device containing the detected layout.";
      };
      freeSpace = mkOption {
        type = types.nullOr types.str;
        default = null;
        internal = true;
        description = "Available free space on the disk (human-readable).";
      };
    };
  };
}
