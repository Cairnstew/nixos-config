# =============================================================================
# nixos-anywhere.nix — Network Install Scripts for NixOS hosts
# =============================================================================
# Purpose: Generates `packages.install-<hostname>` scripts that deploy a NixOS
#          host configuration to a remote machine over SSH using nixos-anywhere.
#
# Workflow:
#   1. PXE-boot the target machine with a NixOS installer
#      (use the `nixos-netboot` Ventoy ISO or the PXE server menu)
#   2. Find the target's IP (DHCP lease from PXE server)
#   3. Run: nix run .#install-<hostname> -- <target-ip>
#
# Outputs:  perSystem.packages.install-<hostname>
# =============================================================================

{ config, lib, inputs, ... }:
let
  inherit (lib) types mkOption;
in
{
  options.nixos-anywhere = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Generate nixos-anywhere install scripts for each host.";
    };

    defaultUser = mkOption {
      type = types.str;
      default = "root";
      description = "Default SSH user for remote installations.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra arguments to pass to every nixos-anywhere invocation.";
      example = [ "--build-on-remote" "--option" "accept-flake-config" "true" ];
    };
  };

  config.perSystem = { pkgs, system, ... }:
    let
      cfg = config.nixos-anywhere;
      nixos-anywhere-pkg = inputs.nixos-anywhere.packages.${system}.nixos-anywhere;

      hosts = lib.filterAttrs
        (_: nixosCfg:
          let
            probed = builtins.tryEval (nixosCfg.config.nixpkgs.hostPlatform.system);
          in
          probed.success && probed.value == system
        )
        config.flake.nixosConfigurations;

      makeInstallScript = hostName: nixosCfg:
        let
          extraArgsStr = lib.concatStringsSep " " cfg.extraArgs;
        in
        pkgs.writeShellScriptBin "install-${hostName}" ''
          set -euo pipefail

          target="''${1:-}"
          if [ -z "$target" ]; then
            echo "Usage: nix run .#install-${hostName} -- <target-ip>"
            echo ""
            echo "Deploys the '${hostName}' NixOS configuration to a remote"
            echo "machine over SSH using nixos-anywhere."
            echo ""
            echo "Prerequisites:"
            echo "  1. PXE-boot the target with a NixOS installer"
            echo "     (use the nixos-netboot.ipxe on Ventoy USB"
            echo "      or the PXE server menu)"
            echo "  2. Ensure network connectivity between this machine"
            echo "     and the target"
            echo "  3. SSH access to ${cfg.defaultUser}@<target-ip>"
            exit 1
          fi

          echo "==> Deploying '${hostName}' to ${cfg.defaultUser}@$target ..."
          exec \
            ${nixos-anywhere-pkg}/bin/nixos-anywhere \
            ${extraArgsStr} \
            --flake ".#${hostName}" \
            "${cfg.defaultUser}@$target"
        '';
    in
    lib.mkIf cfg.enable {
      packages = lib.mapAttrs' makeInstallScript hosts;
    };
}

