{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption types;
  cfg = config.my.programs.houdini;

  # SideFX Labs — the free, open-source toolset from SideFX (hundreds of HDAs,
  # shelves, Python modules, VEX functions, and UI extensions).
  # https://github.com/sideeffects/SideFXLabs/releases/tag/22.0.459
  # Pinned to the 22.0 production build, matching Houdini 22.0.x. The whole
  # repo is laid out as a Houdini package, so fetching the source tarball at a
  # release tag is exactly what the launcher installs from.
  labsSrc = pkgs.fetchzip {
    url = "https://github.com/sideeffects/SideFXLabs/archive/refs/tags/22.0.459.tar.gz";
    hash = "sha256-/GABGDD5NlC8hKfW2ZW4r2Bb/7kAyQmyAlVv7GDVHCU=";
  };

  # Replicate the layout the Houdini Launcher's `install-package` command
  # produces in `/opt/sidefx/sidefx_packages`: the package file sitting next to
  # a `SideFXLabs22.0/` contents directory. The upstream `SideFXLabs.json`
  # computes `$SIDEFXLABS` as `$HOUDINI_PACKAGE_PATH/SideFXLabs22.0`, where
  # `$HOUDINI_PACKAGE_PATH` is the directory containing the package file —
  # i.e. $out here. Houdini discovers this package via `HOUDINI_PACKAGE_DIR`
  # (set below), exactly like reading `/opt/sidefx/sidefx_packages`.
  labsPackage = pkgs.runCommand "sidefxlabs-22.0.459" { src = labsSrc; } ''
    mkdir -p $out/SideFXLabs22.0
    cp -a $src/. $out/SideFXLabs22.0/
    cp $src/SideFXLabs.json $out/SideFXLabs22.0.json
  '';
in
{
  options.my.programs.houdini.labs = {
    enable = mkEnableOption "SideFX Labs, the free open-source toolset (hundreds of HDAs, shelves, and Python tools)";
    package = mkOption {
      type = types.package;
      default = labsPackage;
      defaultText = lib.literalExpression "sidefxlabs 22.0.459 (pinned build)";
      description = ''
        The SideFX Labs package to install. The default is pinned to the 22.0
        production build and expects the launcher layout: a `SideFXLabs<X.Y>.json`
        package file at the output root next to a `SideFXLabs<X.Y>/` contents
        directory. When switching Houdini major versions, point this at a Labs
        package built for that version (the default's `enable` guard only
        activates it for Houdini 22.0 – 22.4).
      '';
    };
  };

  # `HOUDINI_PACKAGE_DIR` is one of the directories Houdini scans at startup
  # for package files. Pointing it at the output root makes the Labs packages
  # (toolbar shelves, otls, python, ...) load on every launch. It is additive:
  # `~/houdini<ver>/packages` and `$HFS/packages` are still scanned, so other
  # packages (e.g. fxhoudinimcp) keep working.
  config = mkIf (cfg.enable && cfg.labs.enable) {
    environment.sessionVariables.HOUDINI_PACKAGE_DIR = "${cfg.labs.package}";
  };
}
