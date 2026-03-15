{ flake, pkgs, lib, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    self.nixos-vscode-server.nixosModules.default
  ];

  options.my.services.vscode-server = {
    enable = lib.mkEnableOption "VSCode Server";
  };

  config = lib.mkIf config.my.services.vscode-server.enable {
    services.vscode-server.enable = true;
  };
}