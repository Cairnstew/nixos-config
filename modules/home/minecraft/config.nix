{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.minecraft;

  defaultLauncher =
    let
      base = if cfg.launcher == "prismlauncher" then pkgs.prismlauncher else pkgs.modrinth-app;
    in
    if cfg.jdks == [ ]
    then base
    else base.override { inherit (cfg) jdks; };

  launcher = if cfg.package != null then cfg.package else defaultLauncher;

  # Wrap prismlauncher with --dir so all data lives on an external drive.
  # symlinkJoin keeps the package's .desktop entry / icons; the wrapper shadows
  # bin/prismlauncher so every invocation (menus, gamescope, CLI) passes --dir.
  launcherWithDir =
    if cfg.dataDir == null || cfg.launcher != "prismlauncher"
    then launcher
    else
      let
        wrapper = pkgs.writeShellScriptBin "prismlauncher" ''
          exec ${lib.getExe launcher} --dir "${cfg.dataDir}" "$@"
        '';
      in
      pkgs.symlinkJoin {
        name = "prismlauncher-data-dir";
        paths = [ wrapper launcher ];
      };
in
{
  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    home.packages =
      [ launcherWithDir ]
      ++ cfg.extraPackages
      ++ lib.optionals cfg.gamescope.enable [
        (pkgs.writeShellScriptBin "minecraft-gamescope" ''
          exec ${cfg.gamescope.package}/bin/gamescope -- ${lib.getExe launcherWithDir} "$@"
        '')
      ];
  };
}
