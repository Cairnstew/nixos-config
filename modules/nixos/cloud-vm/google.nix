{ config, lib, ... }:

let
  cfg = config.my.cloud-vm;
in {
  config = lib.mkIf (cfg.enable && cfg.provider == "google") {
    boot.loader.grub = {
      device     = lib.mkDefault cfg.diskDevice;
      efiSupport = lib.mkDefault false;
    };

    boot.initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
    ];

    networking.useDHCP = lib.mkDefault true;

    # GCP serial console
    boot.kernelParams = [ "console=ttyS0" ];
  };
}