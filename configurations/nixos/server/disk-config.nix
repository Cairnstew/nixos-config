{ lib, ... }: {
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
          };
        };
      };
    };
  };
}
