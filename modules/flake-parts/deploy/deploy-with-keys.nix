{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy-with-keys = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos-with-keys";
        runtimeInputs = [
          inputs.nixos-deploy-tool.packages.${system}.default
          inputs.nixos-anywhere.packages.${system}.default
        ];
        text = ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: deploy-with-keys [--key <age-keyfile>] <hostname> [<ssh-address>] [-- nixos-anywhere options]"
            echo ""
            echo "Deploy NixOS with pre-generated SSH host key via nixos-deploy-tool."
            echo ""
            echo "Examples:"
            echo "  deploy-with-keys desktop"
            echo "  deploy-with-keys --key /etc/ssh/ssh_host_ed25519_key desktop"
            echo "  deploy-with-keys desktop 192.168.1.100"
            exit 1
          fi

          # Warm flake eval cache so nixos-deploy's internal eval shows progress
          nix flake show --json . > /dev/null || true
          exec nixos-deploy deploy with-keys "$@"
        '';
      };
      meta.description = "Deploy NixOS with pre-generated SSH host key via nixos-deploy-tool — replaces the old deploy-with-keys shell wrapper";
    };
  };
}
