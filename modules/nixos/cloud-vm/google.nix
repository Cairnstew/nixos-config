{ config, lib, modulesPath, ... }:

let
  cfg = config.my.cloud-vm;
in {
  config = lib.mkIf (cfg.enable && cfg.provider == "google") {
    imports = [
      "${modulesPath}/virtualisation/google-compute-image.nix"
    ];
  };
}