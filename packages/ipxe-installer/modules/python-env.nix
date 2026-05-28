# Python environment setup for uv2nix
{ pkgs, inputs, cfg, buildSystemOverrides ? { } }:
let
  python = cfg.pythonPackage;

  # Load workspace from uv.lock
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ../.; };

  # Overlay that turns the workspace into a Python package set
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

  # Editable overlay for dev shell
  editableOverlay = workspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; };

  # Build system overlay from pyproject-build-systems
  buildSystemOverlay = inputs.pyproject-build-systems.overlays.default;

  # Combine overlays to create the Python package set
  basePythonSets =
    (pkgs.callPackage inputs.pyproject-nix.build.packages { inherit python; }).overrideScope (
      pkgs.lib.composeManyExtensions [
        buildSystemOverlay
        overlay
      ]
    );

in
{
  inherit python workspace basePythonSets editableOverlay;
  devEnv = basePythonSets.overrideScope editableOverlay;
}
