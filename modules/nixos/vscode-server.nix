{ flake, config, pkgs, lib, ... }:
let
  inherit (flake) inputs;
in
{
  imports = [
    inputs.nixos-vscode-server.nixosModules.default
  ];

  options.my.services.vscode-server = {
    enable = lib.mkEnableOption "VSCode Server";
  };

  config = lib.mkIf config.my.services.vscode-server.enable {
    services.vscode-server.enable = true;
  };
}