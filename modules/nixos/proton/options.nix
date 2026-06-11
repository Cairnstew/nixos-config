{ lib, ... }:
let
  inherit (lib) mkOption mkEnableOption types;
in
{
  options.my.programs.proton = {
    enable = mkEnableOption "Enhanced Proton support (GE-Proton, extra compat packages)";

    ge = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Add GE-Proton (proton-ge-bin) to Steam compatibility tools. GE-Proton adds media codec patches and game-specific fixes beyond Valve's upstream Proton.";
      };
    };

    protonup-qt = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Install ProtonUp-Qt graphical manager for installing and managing GE-Proton and Wine-GE versions.";
      };
    };

    extraCompatPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Additional packages to add to programs.steam.extraCompatPackages. Must have a steamcompattool output.";
    };
  };
}
