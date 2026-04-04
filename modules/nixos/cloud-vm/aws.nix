{ config, lib, ... }:

let
  cfg = config.my.cloud-vm;
in {
  config = lib.mkIf (cfg.enable && cfg.provider == "aws") {
    boot.loader.grub = {
      efiSupport    = false;
      efiInstallAsRemovable = false;
    };

    boot.initrd.availableKernelModules = [
      "xen_blkfront"
      "xen_netfront"
      "nvme"
    ];

    networking.useDHCP = lib.mkDefault true;
  };
}