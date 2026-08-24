{ config, lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.my.programs.houdini;
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
        Mutually exclusive with `localLicenseServer.enable`.
      '';
    };

    localLicenseServer = {
      enable = mkEnableOption "SideFX's sesinetd local license server daemon (listens on port 1715)";
    };

    redeemNonCommercial = {
      enable = mkEnableOption "automatic 30-day renewal of Houdini Apprentice (NC) licenses via the SideFX License API (enables localLicenseServer automatically)";

      serverCode = mkOption {
        type = types.str;
        description = ''
          Server code from `sesictrl print-server`. Run this once after the
          first `sesinetd` start and paste the value here — it is your
          sesinetd instance's unique identifier and only changes on reinstall.

          Obtain it with:

          ```bash
          sudo sesictrl print-server
          ```

          or from the License Administrator GUI (Help → Diagnostics).
        '';
      };

      serverName = mkOption {
        type = types.str;
        default = config.networking.hostName;
        defaultText = lib.literalExpression "config.networking.hostName";
        description = "Server name sent to the SideFX License API. Defaults to the system hostname.";
      };

      version = mkOption {
        type = types.str;
        default = lib.versions.majorMinor cfg.package.passthru.unwrapped.version;
        defaultText = lib.literalExpression ''
          lib.versions.majorMinor cfg.package.passthru.unwrapped.version
        '';
        example = "22.0";
        description = "Houdini major.minor version to request licenses for.";
      };

      products = mkOption {
        type = types.listOf types.str;
        default = [ "HOUDINI-NC" "RENDER-NC" ];
        example = [ "HOUDINI-NC" ];
        description = ''
          Non-commercial products to license. Defaults to both Houdini-NC
          and Render-NC so each Apprentice install gets the full toolset.
        '';
      };
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
