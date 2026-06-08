{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy-test = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos-test";
        runtimeInputs = [
          inputs.nixos-deploy-tool.packages.${system}.default
          inputs.nixos-anywhere.packages.${system}.default
        ];
        text = ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: deploy-nixos-test <hostname> [-- nix build flags]"
            echo ""
            echo "Validate a host config via nixos-deploy-tool VM test."
            echo ""
            echo "Examples:"
            echo "  deploy-nixos-test desktop"
            echo "  deploy-nixos-test laptop --show-trace"
            exit 1
          fi

          # Warm flake eval cache so nixos-deploy's internal eval shows progress
          nix flake show --json . > /dev/null || true
          exec nixos-deploy deploy test "$@"
        '';
      };
      meta.description = "VM-test a NixOS host config via nixos-deploy-tool — replaces the old nixos-anywhere --vm-test shell wrapper";
    };
  };
}
