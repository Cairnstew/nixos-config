{ flake, config, lib, ... }:
let
  cfg = config.my.programs.vscode.server;
in
{
  imports = [
    "${flake.inputs.nixos-vscode-server}/modules/vscode-server/default.nix"
  ];

  options.my.programs.vscode.server = {
    enable = lib.mkEnableOption "VS Code server (fixes Remote-SSH/WSL on NixOS by patching dynamically linked Node binaries)";
  };

  config = lib.mkIf cfg.enable {
    services.vscode-server.enable = true;
  };
}
