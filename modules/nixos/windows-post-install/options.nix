{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.windowsPostInstall = {
    enable = mkEnableOption "post-install EFI boot order recovery for Windows dual-boot";

    autoFixBootOrder = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Automatically restore GRUB as default EFI boot entry after Windows install.
        Windows Setup typically makes itself the first boot entry.
        This service detects that and restores GRUB priority.
      '';
    };
  };
}
