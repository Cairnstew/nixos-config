{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.build-iso = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "build-iso";
        runtimeInputs = [ inputs.nixos-deploy-tool.packages.${system}.default ];
        text = ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: build-iso <name>"
            echo ""
            echo "Build a live ISO via nixos-deploy-tool."
            echo ""
            echo "Examples:"
            echo "  build-iso deploy"
            exit 1
          fi

          # Warm flake eval cache so nixos-deploy's internal eval shows progress
          nix flake show --json . > /dev/null || true
          exec nixos-deploy iso build "$@"
        '';
      };
      meta.description = "Build a live ISO using nixos-deploy-tool";
    };

    apps.iso-list = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "iso-list";
        runtimeInputs = [ inputs.nixos-deploy-tool.packages.${system}.default ];
        text = ''
          # Warm flake eval cache so nixos-deploy's internal eval shows progress
          nix flake show --json . > /dev/null || true
          exec nixos-deploy iso list "$@"
        '';
      };
      meta.description = "List available ISO definitions via nixos-deploy-tool";
    };

    apps.iso-info = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "iso-info";
        runtimeInputs = [ inputs.nixos-deploy-tool.packages.${system}.default ];
        text = ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: iso-info <name>"
            exit 1
          fi

          # Warm flake eval cache so nixos-deploy's internal eval shows progress
          nix flake show --json . > /dev/null || true
          exec nixos-deploy iso info "$@"
        '';
      };
      meta.description = "Show ISO configuration details via nixos-deploy-tool";
    };
  };
}
