{ config, pkgs, lib, ... }:

let
  cfg = config.my.services.brasero;
in
{
  ######################
  # Options
  ######################
  options.my.services.brasero = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Brasero disc burning support.";
    };
  };

  ######################
  # Implementation
  ######################
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      brasero
    ];
  };
}
