{ config, pkgs, lib, ... }:
let
  cfg = config.my.services.udiskie;
in
{
  options.my.services.udiskie = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable udiskie automounter for removable media";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.udiskie;
      description = "The udiskie package to use";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udiskie = {
      enable = true;
      package = cfg.package;
    };
  };
}