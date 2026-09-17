{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.balatro = {
    enable = mkEnableOption "Balatro card game support";

    multiplayer = {
      enable = mkEnableOption "Balatro Multiplayer mod (installs launcher and mod files)";

      launcher = {
        version = mkOption {
          type = types.str;
          default = "1.0.18";
          description = "Balatro Multiplayer Launcher version to install.";
        };
      };

      mod = {
        version = mkOption {
          type = types.str;
          default = "0.5.5";
          description = "Balatro Multiplayer mod version to install.";
        };
      };
    };
  };
}
