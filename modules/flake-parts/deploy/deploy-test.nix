{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy-test = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos-test";
        runtimeInputs = [ inputs.nixos-anywhere.packages.${system}.default ];
        text = ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: deploy-nixos-test <hostname> [-- extra nix build flags]"
            echo ""
            echo "Validate a host config via nixos-anywhere VM test (no SSH target needed)."
            echo ""
            echo "Examples:"
            echo "  deploy-nixos-test desktop"
            echo "  deploy-nixos-test laptop --show-trace"
            exit 1
          fi

          host="$1"
          shift

          host_dir="./configurations/nixos/$host"
          if [ ! -d "$host_dir" ]; then
            echo "Error: host directory not found at $host_dir"
            echo "Make sure you are in the flake root and the host exists."
            exit 1
          fi

          echo "Running VM test for $host — no target machine needed."
          echo "This validates the NixOS config, disko layout, and installation."
          echo ""

          exec nixos-anywhere --vm-test --flake ".#$host" "$@"
        '';
      };
      meta.description = "VM-test a NixOS host config via nixos-anywhere — validates disko layout and install without a target machine";
    };
  };
}
