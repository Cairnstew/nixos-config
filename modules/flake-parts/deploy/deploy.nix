{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos";
        runtimeInputs = [
          inputs.nixos-deploy-tool.packages.${system}.default
          inputs.nixos-anywhere.packages.${system}.default
        ];
        text = ''
          set -euo pipefail

          # Usage: deploy-nixos [--extra-args <args>] <hostname> [<ssh-address>]
          EXTRA_ARGS=""

          while [[ $# -gt 0 ]]; do
            case "$1" in
              --extra-args)
                EXTRA_ARGS="$2"
                shift 2
                ;;
              --help|-h)
                echo "Usage: deploy-nixos [--extra-args <args>] <hostname> [<ssh-address>]"
                echo ""
                echo "Examples:"
                echo "  deploy-nixos desktop"
                echo "  deploy-nixos desktop nixos@nixos"
                echo "  deploy-nixos --extra-args '--disko-mode mount' desktop nixos@nixos"
                exit 0
                ;;
              --*)
                echo "Unknown option: $1"
                exit 1
                ;;
              *)
                break
                ;;
            esac
          done

          if [ $# -lt 1 ]; then
            echo "Usage: deploy-nixos [--extra-args <args>] <hostname> [<ssh-address>]"
            exit 1
          fi

          HOST="$1"
          ADDR="''${2:-}"

          # Change to flake root so relative paths resolve
          cd "''${FLAKE_ROOT:-.}"

          # Warm flake eval cache so nixos-deploy's internal eval shows progress
          nix flake show --json . > /dev/null || true

          if [ -n "$EXTRA_ARGS" ]; then
            # Word-split EXTRA_ARGS into an array for safe passing
            eval "set -- $EXTRA_ARGS"
            EXTRA_ARR=("$@")
            if [ -n "$ADDR" ]; then
              exec nixos-anywhere --flake ".#$HOST" "''${EXTRA_ARR[@]}" "$ADDR"
            else
              exec nixos-anywhere --flake ".#$HOST" "''${EXTRA_ARR[@]}" "$HOST"
            fi
          else
            if [ -n "$ADDR" ]; then
              exec nixos-deploy deploy run "$HOST" --addr "$ADDR"
            else
              exec nixos-deploy deploy run "$HOST"
            fi
          fi
        '';
      };
      meta.description = "Deploy NixOS to a remote host using nixos-deploy-tool — replaces the old nixos-anywhere shell wrapper";
    };
  };
}
