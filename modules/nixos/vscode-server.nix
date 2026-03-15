{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
    imports = [ flake.inputs.vscode-server.nixosModules.default ];

    options.my.services.vscode-server = {
      enable = lib.mkEnableOption "VSCode Server";
    };

    config = lib.mkIf config.my.services.vscode-server.enable {
      services.vscode-server.enable = true;
    };
}