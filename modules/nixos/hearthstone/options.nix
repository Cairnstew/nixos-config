{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.hearthstone = {
    enable = mkEnableOption "Hearthstone — native launcher, no Wine/Battle.net required";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "hearthstone-linux-gui package to use. Defaults to the flake input.";
    };

    dataDir = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/mnt/media/hearthstone";
      description = ''
        Directory for Hearthstone game data (the "game" subdirectory).
        Uses ~/.local/share/hearthstone-linux-gui by default.
        Set to a path on a large drive (e.g. /mnt/media/hearthstone)
        to save space on the system SSD.
      '';
    };

  };
}
