{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos";
        runtimeInputs = [ inputs.nixos-anywhere.packages.${system}.default ];
        text = ''
          set -euo pipefail

          if [ $# -lt 2 ]; then
            echo "Usage: deploy-nixos <hostname> <ssh-address> [-- nixos-anywhere options]"
            echo ""
            echo "Examples:"
            echo "  deploy-nixos server 192.168.1.100"
            echo "  deploy-nixos desktop nixos@192.168.1.100"
            exit 1
          fi
          host="$1"
          addr="$2"
          shift 2

          hw_config="./configurations/nixos/$host/hardware-configuration.nix"
          disk_config="./configurations/nixos/$host/disk-config.nix"

          if [ ! -f "$hw_config" ]; then
            echo "Error: hardware config not found at $hw_config"
            echo "Make sure you are in the flake root and the host directory exists."
            exit 1
          fi

          # Only prepend root@ if no user part is present in the address
          case "$addr" in
            *@*) target_host="$addr" ;;
            *)   target_host="root@$addr" ;;
          esac

          if [ -f "$disk_config" ]; then
            echo "Deploying $host with disko (disk-config.nix found)"
            exec nixos-anywhere \
              --flake ".#$host" \
              --disk-config "$disk_config" \
              --generate-hardware-config nixos-generate-config "$hw_config" \
              --target-host "$target_host" \
              "$@"
          else
            echo "Deploying $host without disko (useExisting or manual partition layout)"
            echo "Note: Target must already be partitioned."
            exec nixos-anywhere \
              --phases kexec,install,reboot \
              --flake ".#$host" \
              --generate-hardware-config nixos-generate-config "$hw_config" \
              --target-host "$target_host" \
              "$@"
          fi
        '';
      };
      meta.description = "Deploy NixOS to a remote host using nixos-anywhere";
    };
  };
}
