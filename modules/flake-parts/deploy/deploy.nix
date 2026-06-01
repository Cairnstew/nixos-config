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
            echo "Usage: deploy-nixos <hostname> [<ssh-address>] [-- nixos-anywhere options]"
            echo ""
            echo "Examples:"
            echo "  deploy-nixos desktop                    # Tailscale (nixos@nixos)"
            echo "  deploy-nixos server 192.168.1.100"
            echo "  deploy-nixos desktop nixos@nixos -- --disko-mode mount"
            exit 1
          fi

          host="$1"
          addr="$2"
          shift 2

          host_dir="./configurations/nixos/$host"

          if [ ! -d "$host_dir" ]; then
            echo "Error: host directory not found at $host_dir"
            echo "Make sure you are in the flake root and the host directory exists."
            exit 1
          fi

          case "$addr" in
            *@*) target_host="$addr" ;;
            *)   target_host="root@$addr" ;;
          esac

          # Auto-detect hardware config strategy:
          #   facter.json > hardware-configuration.nix > generate
          if [ -f "$host_dir/facter.json" ]; then
            hw_flag="--generate-hardware-config nixos-facter $host_dir/facter.json"
          else
            hw_flag="--generate-hardware-config nixos-generate-config $host_dir/hardware-configuration.nix"
          fi

          # Auto-enable password auth when SSHPASS is set
          env_pass_flag=""
          if [ -n "''${SSHPASS:-}" ]; then
            env_pass_flag="--env-password"
          fi

          # If a disk-config.nix exists the host uses disko — let nixos-anywhere
          # auto-discover disko.devices from the flake config.  Otherwise skip
          # partitioning and assume the disk is already laid out.
          if [ -f "$host_dir/disk-config.nix" ]; then
            echo "Deploying $host with disko (disk-config.nix found)"
            exec nixos-anywhere \
              --print-build-logs \
              --flake ".#$host" \
              $hw_flag \
              $env_pass_flag \
              --target-host "$target_host" \
              "$@"
          else
            echo "Deploying $host without disko — target must already be partitioned."
            exec nixos-anywhere \
              --print-build-logs \
              --phases kexec,install,reboot \
              --flake ".#$host" \
              $hw_flag \
              $env_pass_flag \
              --target-host "$target_host" \
              "$@"
          fi
        '';
      };
      meta.description = "Deploy NixOS to a remote host using nixos-anywhere — auto-detects disko, hardware config, and SSH auth strategy";
    };
  };
}
