{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy-with-keys = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos-with-keys";
        runtimeInputs = [
          inputs.nixos-anywhere.packages.${system}.default
          pkgs.tailscale
          pkgs.openssh
        ];
        text = ''
          set -euo pipefail

          KEYFILE=""

          while [ $# -gt 0 ]; do
            case "$1" in
              --key) KEYFILE="$2"; shift 2 ;;
              --help|-h) break ;;
              --) break ;;
              -*) echo "Unknown flag: $1"; exit 1 ;;
              *) break ;;
            esac
          done

          if [ $# -lt 1 ]; then
            echo "Usage: deploy-with-keys [--key <age-keyfile>] <hostname> [<ssh-address>] [-- nixos-anywhere options]"
            echo ""
            echo "Deploy NixOS with a pre-generated SSH host key:"
            echo "  1. Auto-discover target via Tailscale (if address omitted)"
            echo "  2. Generate ed25519 host key in a secure temp dir"
            echo "  3. Register the public key in secrets/secrets.nix"
            echo "  4. Rekey all secrets for the new host"
            echo "  5. Deploy via nixos-anywhere with --extra-files"
            echo ""
            echo "Options:"
            echo "  --key <path>     Path to age private key for rekeying"
            echo "                   (default: fetch from 1Password)"
            echo ""
            echo "Examples:"
            echo "  deploy-with-keys desktop                            # Auto-discover via Tailscale"
            echo "  deploy-with-keys --key /etc/ssh/ssh_host_ed25519_key desktop"
            echo "  deploy-with-keys desktop 192.168.1.100"
            echo "  deploy-with-keys desktop nixos@nixos"
            exit 1
          fi

          host="$1"
          shift

          FLAKE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")
          cd "$FLAKE_ROOT"
          HOST_DIR="./configurations/nixos/$host"

          if [ ! -d "$HOST_DIR" ]; then
            echo "Error: host directory not found at $HOST_DIR"
            exit 1
          fi

          ORIGINAL_USER="''${SUDO_USER:-$(whoami)}"

          # ── Resolve target address ─────────────────────────────────────────
          TARGET_HOST=""

          case "''${1:-}" in
            --*|"")
              # No address given — auto-discover via Tailscale
              echo "Discovering live ISO via Tailscale ..."
              TS_IP=$(tailscale status 2>/dev/null | awk '/^100\./ && $2 == "nixos" {print $1}')
              if [ -z "$TS_IP" ]; then
                echo "Cannot find 'nixos' node in tailscale status."
                echo "Boot the live ISO and make sure it is connected to your tailnet."
                exit 1
              fi
              echo "Found live ISO at Tailscale IP: $TS_IP"
              TARGET_HOST="root@$TS_IP"
              echo "Deploy target: $TARGET_HOST"
              ;;
            *)
              # Explicit address
              case "$1" in
                *@*) TARGET_HOST="$1" ;;
                *)   TARGET_HOST="root@$1" ;;
              esac
              shift
              ;;
          esac

          # ── Step 1: Generate SSH host key in secure temp dir ──────────────
          TMPDIR=$(mktemp -d)
          chmod 0700 "$TMPDIR"
          trap cleanup EXIT
          cleanup() {
            chown -R "$ORIGINAL_USER:" "$FLAKE_ROOT/secrets" 2>/dev/null || true
            echo "Cleaning up..."; rm -rf "$TMPDIR"
          }

          mkdir -p "$TMPDIR/etc/ssh"
          ssh-keygen -t ed25519 -C "root@$host" -f "$TMPDIR/etc/ssh/ssh_host_ed25519_key" -N "" 2>&1
          chmod 600 "$TMPDIR/etc/ssh/ssh_host_ed25519_key"
          echo "Generated SSH host key for $host"

          # ── Step 2: Extract public key ────────────────────────────────────
          PUBKEY=$(cat "$TMPDIR/etc/ssh/ssh_host_ed25519_key.pub")
          echo "Public key: $PUBKEY"

          # ── Step 3: Register host with secrets ────────────────────────────
          echo ""
          echo "=== Registering $host with secrets system ==="
          nix run .#secrets-add-host -- "$host" "$PUBKEY"

          # ── Step 4: Rekey secrets ─────────────────────────────────────────
          rekey_args=()
          if [ -n "$KEYFILE" ]; then
            rekey_args=(-i "$KEYFILE")
            echo "=== Rekeying secrets (using provided key) ==="
          else
            echo "=== Rekeying secrets (via 1Password) ==="
            echo "You may be prompted to authenticate with 1Password."
          fi
          nix run .#secrets-rekey -- "''${rekey_args[@]}"

          # ── Step 5: Deploy with extra-files ───────────────────────────────
          echo ""
          echo "=== Deploying $host with pre-generated SSH host key ==="
          echo "Target: $TARGET_HOST"

          if [ -f "$HOST_DIR/facter.json" ]; then
            hw_args=(--generate-hardware-config nixos-facter "$HOST_DIR/facter.json")
          else
            hw_args=(--generate-hardware-config nixos-generate-config "$HOST_DIR/hardware-configuration.nix")
          fi

          if [ -n "''${SSHPASS:-}" ]; then
            pass_args=(--env-password)
          else
            pass_args=()
          fi

          if [ -f "$HOST_DIR/disk-config.nix" ]; then
            echo "Deploying with disko (disk-config.nix found)"
            nixos-anywhere \
              --print-build-logs \
              --flake ".#$host" \
              "''${hw_args[@]}" \
              "''${pass_args[@]}" \
              --extra-files "$TMPDIR" \
              --target-host "$TARGET_HOST" \
              "$@"
          else
            echo "Deploying without disko — target must already be partitioned."
            nixos-anywhere \
              --print-build-logs \
              --phases kexec,install,reboot \
              --flake ".#$host" \
              "''${hw_args[@]}" \
              "''${pass_args[@]}" \
              --extra-files "$TMPDIR" \
              --target-host "$TARGET_HOST" \
              "$@"
          fi
        '';
      };
      meta.description = "Deploy NixOS with pre-generated SSH host key — auto-discovers target via Tailscale, registers host key in secrets.nix, rekeys, and deploys via nixos-anywhere with --extra-files";
    };
  };
}
