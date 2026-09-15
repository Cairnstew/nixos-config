{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.steam;
in
{
  config = lib.mkIf cfg.enable {
    # NOTE: allowUnfree is set globally in flake.nix perSystem; setting
    # nixpkgs.config here is dead under home-manager.useGlobalPkgs and only
    # triggers a warning. Do not re-add.
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
