{ config, lib, pkgs, flake, ... }:

let
  cfg = config.my.services.vscode-server;
in
{
  options.my.services.vscode-server = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the VS Code server auto-fix service for NixOS remote SSH";
    };

    installPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Override the VS Code server install path (e.g. ~/.vscode-server-insiders)";
    };
  };

  config = lib.mkIf cfg.enable {
    imports = [
      "${flake.inputs.nixos-vscode-server}/modules/vscode-server/home.nix"
    ];

    services.vscode-server.enable = true;
    services.vscode-server.installPath = lib.mkIf (cfg.installPath != null) cfg.installPath;
  };
}
