{ flake, pkgs, lib, ... }:
let
  inherit (flake) config inputs;
  inherit (inputs) self;
in
{
  environment.systemPackages = [
      (pkgs.vscode-with-extensions.override {
        vscode = pkgs.vscode;
        #vscodeExtensions = with pkgs.vscode-extensions; [
        #  bbenoist.nix
        #  ms-python.python
        #  esbenp.prettier-vscode
        #];
      })
    ];
}
