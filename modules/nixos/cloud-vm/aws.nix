{ flake, config, lib, modulesPath, ... }:

let
  cfg = config.my.cloud-vm;
in {
  imports = [
    #flake.inputs.self.nixosModules.secrets
    "${modulesPath}/virtualisation/amazon-image.nix"
  ];

  #onfig = lib.mkIf cfg.enable {
  #  my.secrets.enable = true;
  #};
}