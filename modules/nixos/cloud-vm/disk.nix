{ flake, config, lib, inputs, ... }:

let
  cfg = config.my.cloud-vm;
in {
  imports = [ flake.inputs.disko.nixosModules.disko ];

  options.my.cloud-vm.diskDevice = lib.mkOption {
    type        = lib.types.str;
    default     = "/dev/nvme0n1";
    description = "Block device to partition (AWS default is /dev/xvda, GCP is /dev/sda)";
    example     = "/dev/sda";
  };

  config = lib.mkIf cfg.enable {
    disko.devices = {
      disk.main = {
        type    = "disk";
        device  = cfg.diskDevice;
        content = {
          type = "gpt";
          partitions = {
            boot = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size    = "512M";
              type    = "EF00";
              content = {
                type       = "filesystem";
                format     = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size    = "100%";
              content = {
                type       = "filesystem";
                format     = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };

    # Override whatever google/amazon modules set for filesystems
    fileSystems."/" = lib.mkForce {
      device = "/dev/disk/by-partlabel/disk-main-root";
      fsType = "ext4";
    };

    fileSystems."/boot" = lib.mkForce {
      device = "/dev/disk/by-partlabel/disk-main-ESP";
      fsType = "vfat";
    };
  };
}