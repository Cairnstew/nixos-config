{ config, lib, pkgs, ... }:

let
  cfg = config.systemModules.graphics;
in
{
  options.systemModules.graphics.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable base graphics stack (OpenGL + 32-bit support).";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
