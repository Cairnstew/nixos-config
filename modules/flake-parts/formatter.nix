# =============================================================================
# formatter.nix — Code Formatting Configuration
# =============================================================================
# Purpose: Configures nixpkgs-fmt as the default formatter for 'nix fmt'
#
# Usage: nix fmt
#        nix fmt -- --check  # Check without modifying
# =============================================================================

{ ... }: {
  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixpkgs-fmt;
  };
}
