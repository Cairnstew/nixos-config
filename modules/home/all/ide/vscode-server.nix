{ pkgs, flake, ... }:
{
  imports = [
    "${flake.inputs.nixos-vscode-server}/modules/vscode-server/home.nix"
  ];

  services.vscode-server.enable = true;
  services.vscode-server.installPath = [
      "$HOME/.vscode-server"          # For standard VS Code (optional if not using it)
      "$HOME/.vscode-server-insiders" # Required for Insiders
    ];
}
