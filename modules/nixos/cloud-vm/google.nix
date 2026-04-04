# google.nix
{ config, lib, modulesPath, ... }:
let
  cfg = config.my.cloud-vm;
in {
  imports = [
    "${modulesPath}/virtualisation/google-compute-image.nix"
  ];

  config = lib.mkIf (cfg.enable && cfg.provider == "google") {
    # google-specific overrides if needed
  };
}