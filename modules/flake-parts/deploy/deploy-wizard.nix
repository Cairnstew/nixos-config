{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy-wizard = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos-wizard";
        runtimeInputs = [
          inputs.nixos-deploy-tool.packages.${system}.default
          inputs.nixos-anywhere.packages.${system}.default
        ];
        text = ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: deploy-nixos-wizard <hostname>"
            echo ""
            echo "Interactive deploy wizard via nixos-deploy-tool."
            echo ""
            echo "Examples:"
            echo "  deploy-nixos-wizard desktop"
            exit 1
          fi

          # Warm flake eval cache so nixos-deploy's internal eval shows progress
          nix flake show --json . > /dev/null || true
          exec nixos-deploy deploy wizard "$@"
        '';
      };
      meta.description = "Interactive deploy wizard via nixos-deploy-tool — replaces the old shell-based wizard";
    };
  };
}
