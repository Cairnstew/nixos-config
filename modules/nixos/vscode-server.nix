{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  nixosModules.vscode-server = { config, pkgs, lib, ... }: {
    imports = [
      self.nixos-vscode-server.nixosModules.default
    ];

    options.services.vscode-server.enable = lib.mkEnableOption "VSCode Server";

    config = lib.mkIf config.services.vscode-server.enable {
      services.vscode-server.enable = true;
    };
  };
}