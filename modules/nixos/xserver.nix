# nixosModules/xserver.nix
{ config, pkgs, lib, ... }:

let
  cfg = config.systemModules.xserver;
in {
  options.systemModules.xserver = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the X server with GPU support";
    };

    videoDriver = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "auto" ];
      description = "The Xorg video drivers to use. Use ['auto'] to auto-detect.";
    };
  };

  config = {
    services.xserver.enable = cfg.enable;

    # Only set videoDrivers if not ["auto"]
    services.xserver.videoDrivers = lib.mkIf (
      cfg.enable && cfg.videoDriver != [ "auto" ]
    ) cfg.videoDriver;
  };
}
