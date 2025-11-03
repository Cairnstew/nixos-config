{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
  
in
{
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      dracula-theme.theme-dracula
      ms-python.python
      ms-toolsai.jupyter
      bbenoist.nix

      #bernhard-42.ocp-cad-viewer       
      #vscodevim.vim
      #yzhang.markdown-all-in-one
    ];
  };
}