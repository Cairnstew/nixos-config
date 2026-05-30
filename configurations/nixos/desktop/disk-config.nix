{ lib, ... }: {
  # Dual-boot: ESP + MSR + Windows + NixOS.
  # Matches the layout created by the Windows answer file (wipe-disk.xml) +
  # the NixOS partition created in free space.
  # For fresh installs, nixos-anywhere will create this layout.
  # For reinstalls on existing partitions, pass --disko-mode mount.
  disko.devices.disk.main = {
    type = "disk";
    device = lib.mkDefault "/dev/sda";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        msr = {
          size = "16M";
          type = "E3C9E316-31B4-4298-89FA-94C9F823F8A5";
        };
        windows = {
          size = "80G";
          type = "0700";
          label = "Windows";
        };
        nixos = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
