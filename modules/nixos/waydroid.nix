{ config, lib, pkgs, ... }:

with lib;

let
  defaultWaydroidPkg = pkgs.waydroid;
  defaultHelperPkg  = pkgs.waydroid-helper;
in
{
  options.my.virtualisation = {
    waydroid = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Waydroid with optional helper and nftables support";
      };

      package = mkOption {
        type = types.package;
        default = defaultWaydroidPkg;
        description = "Waydroid package to use";
      };

      helper = mkOption {
        type = types.package;
        default = defaultHelperPkg;
        description = "Optional Waydroid helper package (Magisk, extensions, etc.)";
      };

    };
  };

  config = mkIf config.my.virtualisation.waydroid.enable {
    virtualisation.waydroid.enable = true;
    virtualisation.waydroid.package = config.my.virtualisation.waydroid.package;

    environment.systemPackages = with config.my.virtualisation.waydroid; [
      helper
      
    ];
  };
}
