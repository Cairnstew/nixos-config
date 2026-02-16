{ flake, config, lib, pkgs, ... }:

let
  cfg = config.hardwareProfiles.vulkan;
in
{
  imports = [
    flake.self.nixosModules.graphics
    flake.self.nixosModules.xserver
  ];


  options.hardwareProfiles.vulkan.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Vulkan loader and validation layers.";
  };

  config = lib.mkIf cfg.enable {
    hardware.graphics.extraPackages = with pkgs; [
      vulkan-loader
      vulkan-validation-layers
    ];

    hardware.graphics.extraPackages32 = with pkgs.pkgsi686Linux; [
      vulkan-loader
    ];

    systemModules.graphics.enable = true;
  };
}
