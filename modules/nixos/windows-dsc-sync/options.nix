{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.windowsDscSync = {
    enable = mkEnableOption "sync DSC YAML from NixOS to Windows partition on rebuild";

    windowsPartition = mkOption {
      type = types.str;
      default = "/dev/disk/by-partlabel/Windows";
      description = "Device path for the Windows partition.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/windows-dsc-sync";
      description = "Temporary mount point for the Windows partition during sync.";
    };

    windowsTargetDir = mkOption {
      type = types.str;
      default = "NixOS";
      description = "Directory on the Windows partition to write DSC config into (relative to root, e.g. 'NixOS' → C:\\NixOS).";
    };
  };
}
