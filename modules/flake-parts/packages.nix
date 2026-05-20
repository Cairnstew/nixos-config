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
# Note: Secrets are disabled for these package builds (safe for CI/hydra).
# =============================================================================

{ config, lib, ... }: {
  perSystem = { system, ... }: {
    packages = lib.mapAttrs
      (hostName: nixosCfg:
        (nixosCfg.extendModules {
          modules = [
            { my.secrets.enable = false; }
          ];
        }).config.system.build.default
      )
      (lib.filterAttrs
        (_: cfg:
          let
            probed = builtins.tryEval (cfg.config.nixpkgs.hostPlatform.system); # ← changed
          in
          probed.success && probed.value == system
        )
        config.flake.nixosConfigurations);
  };
}
