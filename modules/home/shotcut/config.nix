{ config, lib, ... }:

let
  cfg = config.my.programs.shotcut;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
