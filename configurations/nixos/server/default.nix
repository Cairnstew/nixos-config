{ flake, pkgs, ... }:

let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.nixosModules.default
    ./configuration.nix
    #inputs.vscode-server.nixosModules.default
    self.nixosModules.server
    (self + /modules/nixos/linux/nvidia.nix)
    (self + /modules/nixos/linux/docker.nix)
  ];

  #services.vscode-server.enable = true;

  #homeModules.uv.enable = true;
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/aaf609bd-e320-4d13-a9a6-fc2cc5cd0f3a";
    fsType = "ext4";
  };

  
}
