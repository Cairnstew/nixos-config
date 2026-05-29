# =============================================================================
# nixos-flake.nix — nixos-unified Integration and Primary Inputs
# =============================================================================
# Purpose: Wires the nixos-unified module system for autowiring configurations
#          and defines which flake inputs to update via `nix run .#update`.
#
# Inputs:
#   - inputs.nixos-unified — flake module system
#
# Outputs:
#   - imports nixos-unified flakeModules (default + autoWire)
#   - perSystem.packages.default — alias for the activate script
#   - perSystem.nixos-unified.primary-inputs — inputs managed by `.#update`
#
# Consumed by: `nix run`, `nix run .#update`
# =============================================================================

{ inputs, ... }:
{
  imports = [
    inputs.nixos-unified.flakeModules.default
    inputs.nixos-unified.flakeModules.autoWire
  ];
  perSystem = { self', ... }: {
    packages.default = self'.packages.activate;

    # Flake inputs we want to update periodically
    # Run: `nix run .#update`.
    nixos-unified = {
      primary-inputs = [
        "nixpkgs"
        "home-manager"
        "nix-darwin"
        "nixos-unified"
        "omnix"
      ];
    };
  };
}
