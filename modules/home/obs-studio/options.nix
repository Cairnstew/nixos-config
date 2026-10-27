{ lib, pkgs, ... }:

let
  inherit (lib) types;
in
{
  options.my.programs.obs-studio = {
    enable = lib.mkEnableOption "OBS Studio";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.obs-studio;
      defaultText = lib.literalExpression "pkgs.obs-studio";
      description = "The OBS Studio package to use.";
    };

    plugins = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.obs-studio-plugins.wlrobs ]";
      description = ''
        OBS Studio plugins to wrap into the installed package (via Home
        Manager's `wrapOBS`). The attribute set is `pkgs.obs-studio-plugins`.
      '';
    };

    recordingPath = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/mnt/data/obs-recordings";
      description = ''
        Recording output directory written into OBS profiles (Simple and
        Advanced output, including the FFmpeg output path). `null` leaves OBS's
        own default alone, which on Linux is `$HOME`.

        Applied by a Home Manager activation script on every switch, so it also
        overrides a path changed in the OBS UI. The directory must already exist
        and be writable by the user; paths outside the home directory need a
        root-owned tmpfiles rule in the host config.
      '';
    };
  };
}
