{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  
in
{
  programs.vscode = {
    enable = true;
    #defaultEditor = true;
    profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
        ms-python.python
        ms-toolsai.jupyter
        bbenoist.nix
        ms-vscode-remote.vscode-remote-extensionpack
    ];
    };

  };
}
