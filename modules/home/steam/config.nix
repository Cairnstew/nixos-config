{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.steam;
in
{
  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages =
      with pkgs;
      [
        steam
        steam-run
        steamcmd
      ]
      ++ cfg.extraPackages;

    home.sessionVariables = lib.mkIf (cfg.extraCompatPaths != null) {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = cfg.extraCompatPaths;
    };
  };
}
