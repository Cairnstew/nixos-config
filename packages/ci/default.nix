# =============================================================================
# ci/default.nix — Local CI Runner
# =============================================================================
# Purpose: Runs CI pipelines locally using omnix for nix builds and zellij
#          for terminal multiplexing/layout.
#
# Not in nixpkgs: Custom integration script for personal workflow.
#
# Usage: ci
# Prerequisites: Must be run from a project directory with a zellij layout.
# =============================================================================

{ writeShellApplication, omnix, zellij, ... }:

writeShellApplication {
  name = "ci";
  meta = {
    description = "Run CI locally with omnix and zellij";
    longDescription = ''
      Runs CI pipelines locally using:
      - omnix: For building and checking Nix expressions
      - zellij: For terminal multiplexing and layout management
      
      Uses the layout defined in layout.kdl for organized build output.
      
      Usage: ci
      Prerequisites: Run from project root with appropriate layout.kdl
    '';
    homepage = "https://github.com/juspay/omnix";
    license = "MIT";
    mainProgram = "ci";
  };
  runtimeInputs = [ omnix zellij ];
  text = ''
    PRJ=$(basename "$(pwd)")
    zellij --layout ${./layout.kdl} attach --create "$PRJ"-ci --force-run-commands
  '';
}
