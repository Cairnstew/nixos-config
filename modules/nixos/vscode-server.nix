{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;

in
{
 imports = [
    self.nixos-vscode-server.nixosModules.default
 ];

  services.vscode-server.enable = true;

}
