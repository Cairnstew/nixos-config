{ config, lib, ... }:
{
  options.my.services.vscode-server = {
    enable = lib.mkEnableOption "VSCode Server";
  };

  config = lib.mkIf config.my.services.vscode-server.enable {
    services.vscode-server.enable = true;
  };
}