{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.yazi;
in
{
  options.my.programs.yazi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Yazi file manager";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
    };
  };
}