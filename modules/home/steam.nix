{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.steam;
in
{
  options.my.programs.steam = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Steam and related packages.";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
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

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages =
      with pkgs;
      [
        steam
        steam-run   # useful FHS env for some games
        steamcmd
      ]
      ++ cfg.extraPackages;

    home.sessionVariables = lib.mkIf (cfg.extraCompatPaths != null) {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = cfg.extraCompatPaths;
    };
  };
}
  