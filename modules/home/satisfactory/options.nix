{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.satisfactory = {
    enable = mkEnableOption "Satisfactory modding tools (ficsit-cli, mod management)";

    gameDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "$HOME/.steam/steam/steamapps/common/Satisfactory";
      description = ''
        Path to the Satisfactory game installation directory.
        When <literal>null</literal>, ficsit-cli will auto-detect the
        installation from Steam library paths.
      '';
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages to install alongside the modding tools.";
    };
  };
}
