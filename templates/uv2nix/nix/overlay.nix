{ pkgs, workspace, pyproject-build-systems, pyproject-nix, pythonSet }:

final: prev: {

  uv2nix-template = pythonSet."uv2nix-template";

  uv2nix-template-env = pythonSet.mkVirtualEnv "app-env" workspace.deps.default;

}
