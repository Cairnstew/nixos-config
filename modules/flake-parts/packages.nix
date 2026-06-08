# =============================================================================
# packages.nix — Per-Host Package Exports
# =============================================================================
# Purpose: Exports each NixOS configuration as a buildable package for its
#          target platform, enabling `nix build .#<hostname>`.
#
# Inputs:
#   - config.flake.nixosConfigurations — all NixOS host configurations
#
# Outputs: perSystem.packages.<hostname> — activatable system packages
#
# Note: Secrets and tailscale are disabled for package builds so they
#       evaluate cleanly in CI without requiring encrypted .age files.
# =============================================================================

{ config, lib, ... }: {
  perSystem = { system, ... }: {
    packages = lib.mapAttrs
      (hostName: nixosCfg:
        (nixosCfg.extendModules {
          modules = [
            {
              agenixManager.enable = lib.mkForce false;
              services.tailscale.enable = lib.mkForce false;
              services.tailscale-manager.enable = lib.mkForce false;
            }
          ];
        }).config.system.build.default
      )
      (lib.filterAttrs
        (_: cfg:
          let
            probed = builtins.tryEval (cfg.config.nixpkgs.hostPlatform.system);
          in
          probed.success && probed.value == system
        )
        config.flake.nixosConfigurations);
  };
}
