# aws.nix
{ config, lib, modulesPath, ... }:
let
  cfg = config.my.cloud-vm;
in {
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  config = lib.mkIf (cfg.enable && cfg.provider == "aws") {
    # aws-specific overrides if needed
  };
}