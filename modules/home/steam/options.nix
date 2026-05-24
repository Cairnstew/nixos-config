{ config, lib, pkgs, ... }:
{
  options.my.programs.steam = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Steam and related packages.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra Steam-related packages to install.";
    };

    extraCompatPaths = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Extra compatibility tool paths for Steam Proton.
        Example: "$HOME/.steam/root/compatibilitytools.d"
      '';
    };
  };
}
