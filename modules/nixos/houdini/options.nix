{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.programs.houdini = {
    enable = mkEnableOption "SideFX Houdini 3D animation software";

    package = mkOption {
      type = types.package;
      default = pkgs.houdini;
      defaultText = lib.literalExpression "pkgs.houdini";
      description = "The Houdini package to install.";
    };

    licenseServer = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "license-server.local:1715";
      description = ''
        Houdini license server address in `host:port` format.
        When set, configures the `sesi_license` environment and
        license client files to point to a remote license server
        instead of requiring a local `sesinetd` daemon.
      '';
    };

    extraEnv = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        HOUDINI_TEMP_DIR = "/mnt/scratch/houdini_temp";
      };
      description = ''
        Extra environment variables to set for Houdini sessions.
        These are added to the user's profile via
        `environment.sessionVariables`.
      '';
    };
  };
}
