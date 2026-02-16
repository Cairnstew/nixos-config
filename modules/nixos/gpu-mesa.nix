{ flake, config, lib, pkgs, ... }:

let
  cfg = config.hardwareProfiles.gpu.mesa;
in
{
  imports = [
    flake.self.nixosModules.graphics
    flake.self.nixosModules.xserver
  ];

  options.hardwareProfiles.gpu.mesa.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Mesa-based GPU drivers (Intel / AMD).";
  };

  config = lib.mkIf cfg.enable {
    systemModules.xserver.videoDriver = [ "modesetting" ];
    systemModules.graphics.enable = true;
  };
}
