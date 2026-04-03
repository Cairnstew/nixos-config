{ config, lib, modulesPath, ... }:

let
  cfg = config.my.cloud-vm;
in {
  config = lib.mkIf (cfg.enable && cfg.provider == "aws") {
    imports = [
      "${modulesPath}/virtualisation/amazon-image.nix"
    ];
  };
}