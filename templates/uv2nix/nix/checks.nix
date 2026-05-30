{ pkgs, lib, pythonSet, system }:

let
  pkg = pythonSet."uv2nix-template";
in

{

  uv2nix-template-build = pkg;

  uv2nix-template-venv = pythonSet.mkVirtualEnv "app-env" { uv2nix-template = [ ]; };

}
