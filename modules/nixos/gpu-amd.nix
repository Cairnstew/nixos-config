{ flake, config, lib, pkgs, ... }:

let
  cfg = config.hardwareProfiles.gpu.amd;
in
{
  imports = [
    flake.self.nixosModules.graphics
    flake.self.nixosModules.xserver
  ];

  options.hardwareProfiles.gpu.amd.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable AMDGPU driver explicitly.";
  };

  config = lib.mkIf cfg.enable {
    systemModules.xserver.videoDriver = [ "amdgpu" ];
    systemModules.graphics.enable = true;

  };
}


