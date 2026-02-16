{ config, pkgs, lib, flake, ... }:

let
  cfg = config.my.programs.freecad;
in
{
  ######################
  # Options Definition #
  ######################
  options.my.programs.freecad = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to install FreeCAD for the user.";
    };
  };

  ##################
  # Configurations #
  ##################
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      freecad
    ];
  };
}
