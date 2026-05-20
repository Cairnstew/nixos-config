# Python environment setup for uv2nix
{ pkgs, inputs, cfg, buildSystemOverrides ? {} }:
let
  python = cfg.pythonPackage;

  # Load workspace from uv.lock
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ../.; };

  # Overlays for package building
  overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
  editableOverlay = workspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; };

  # Default build system overrides for common packages
  # Users can extend these via the uv2nix.buildSystemOverrides option
  defaultBuildSystemOverrides = {
    # Core packaging tools
    packaging.flit-core = [ ];
    tomli.flit-core = [ ];
    pip = { setuptools = [ ]; wheel = [ ]; };

    # Build backends
    hatchling = { pathspec = [ ]; pluggy = [ ]; packaging = [ ]; trove-classifiers = [ ]; };

    # Common packages that often need build system hints
    setuptools.setuptools = [ ];
    wheel.wheel = [ ];
    flit-core.flit-core = [ ];
  };

  # Merge user overrides with defaults
  allBuildSystemOverrides = defaultBuildSystemOverrides // buildSystemOverrides;

  # Create overlay for build system overrides
  mkBuildSystemOverlay = final: prev:
    builtins.mapAttrs (name: spec:
      if builtins.hasAttr name prev then
        prev.${name}.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem spec;
        })
      else
        prev.${name} or (builtins.trace "buildSystemOverrides: package '${name}' not in lockfile, skipping" null)
    ) (builtins.intersectAttrs prev allBuildSystemOverrides);

  # Editable packages overlay - enables editable installs for the project package
  editablesOverlay = final: prev:
    if builtins.hasAttr cfg.name prev then {
      ${cfg.name} = prev.${cfg.name}.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.editables ];
      });
    } else prev;

  # Base Python package set with all overlays applied
  basePythonSets =
    (pkgs.callPackage inputs.pyproject-nix.build.packages { inherit python; }).overrideScope (
      pkgs.lib.composeManyExtensions [
        inputs.pyproject-build-systems.overlays.default
        overlay
        mkBuildSystemOverlay
        editablesOverlay
      ]
    );

in
{
  inherit python workspace basePythonSets editableOverlay;
  devEnv = basePythonSets.overrideScope editableOverlay;
}
