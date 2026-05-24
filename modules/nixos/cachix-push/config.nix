{ config, lib, ... }:
let
  cfg = config.my.services.cachix-push;
in
{
  config = lib.mkIf cfg.enable { };
}
