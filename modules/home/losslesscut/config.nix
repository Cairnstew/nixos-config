{ config, lib, ... }:

let
  cfg = config.my.programs.losslesscut;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
