{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy-wizard = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos-wizard";
        runtimeInputs = [
          inputs.nixos-anywhere.packages.${system}.default
          pkgs.openssh
        ];
        text = ''
          set -euo pipefail

          if [ $# -lt 1 ]; then
            echo "Usage: deploy-nixos-wizard <hostname>"
            echo ""
            echo "Connects to the host's live ISO via Tailscale,"
            echo "helps select/create a partition, then deploys."
            exit 1
          fi

          HOST="$1"
          FLAKE_DIR="$PWD"
          DISK_CONFIG="$FLAKE_DIR/configurations/nixos/$HOST/disk-config.nix"
          TAILSCALE_HOST="nixos@nixos.tail685690.ts.net"

          # ── helpers ────────────────────────────────────────────────────
          warn() { printf "\033[33m⚠️  %s\033[0m\n" "$*"; }
          ok()   { printf "\033[32m✓ %s\033[0m\n" "$*"; }
          info() { printf "\033[36m%s\033[0m\n" "$*"; }

          cleanup() {
            [ -n "''${TMPDIR:-}" ] && rm -rf "$TMPDIR"
          }
          trap cleanup EXIT

          echo ""
          info "════════════════════════════════════════════════════"
          info "  NixOS Deploy Wizard — $HOST"
          info "════════════════════════════════════════════════════"
          echo ""

          # Test SSH connectivity
          info "🔍 Testing connection to $TAILSCALE_HOST ..."
          if ! ssh -o ConnectTimeout=5 "$TAILSCALE_HOST" "echo connected" >/dev/null 2>&1; then
            echo "❌ Cannot reach $TAILSCALE_HOST — is the live ISO booted and on Tailscale?"
            exit 1
          fi
          ok "Connected to $TAILSCALE_HOST"

          FLAKE_DIR="$PWD"

          if [ -f "$DISK_CONFIG" ]; then
            # ── Host has disk-config.nix: simple disk selector ────────
            info "📋 Found disk-config.nix — partitioning handled by disko"
            echo ""

            info "📀 Available disks on target:"
            ssh "$TAILSCALE_HOST" "lsblk -o NAME,SIZE,TYPE,MODEL | head -30"
            echo ""

            printf "💾 Enter target disk device (e.g., /dev/nvme0n1): "
            read -r disk_dev
            echo ""

            ok "Deploying to $disk_dev ..."
            exec nix run "$FLAKE_DIR#deploy" -- "$HOST" "$TAILSCALE_HOST" -- --disk-main "$disk_dev"
          fi

          # ── No disk-config.nix: partition wizard (desktop dual-boot) ─
          info "📋 No disk-config.nix — interactive partition setup"
          echo ""

          info "📀 Available disks on target:"
          ssh "$TAILSCALE_HOST" "lsblk -o NAME,SIZE,TYPE,MODEL | head -30"
          echo ""

          printf "💾 Select disk (e.g., /dev/sda): "
          read -r disk_dev
          echo ""

          info "📊 Partition table for $disk_dev:"
          ssh "$TAILSCALE_HOST" "sgdisk -p $disk_dev 2>/dev/null || (parted $disk_dev print 2>/dev/null || fdisk -l $disk_dev)"
          echo ""

          # Look for existing NixOS partition (label = "nixos" or fs = ext4)
          existing=$(ssh "$TAILSCALE_HOST" "lsblk -o NAME,FSTYPE,LABEL -n $disk_dev 2>/dev/null | grep -iE 'ext4.*nixos|nixos.*ext4' | head -1 | awk '{print \$1}'")

          if [ -n "$existing" ]; then
            ok "Found existing NixOS partition: /dev/$existing"
            printf "Reuse it? [Y/n]: "
            read -r reuse
            if [[ "$reuse" =~ ^[Nn] ]]; then
              existing=""
            fi
          fi

          if [ -z "$existing" ]; then
            # Check for free space
            free_info=$(ssh "$TAILSCALE_HOST" "sgdisk -p $disk_dev 2>/dev/null | grep -i 'free\|unallocated' | head -1" || true)

            if [ -n "$free_info" ]; then
              echo ""
              info "Found unallocated space: $free_info"
              printf "Create NixOS partition? [Y/n]: "
              read -r create
              if [[ "$create" =~ ^[Nn] ]]; then
                echo "❌ Aborting. Create the partition manually and re-run."
                exit 1
              fi

              # Ask for size
              printf "Partition size (e.g., 50G, or press Enter for 100%% of free space): "
              read -r part_size
              echo ""

              info "Creating partition on $disk_dev ..."
              if [ -z "$part_size" ]; then
                ssh "$TAILSCALE_HOST" "sgdisk -n 0:0:0 -t 0:8300 -c 0:nixos $disk_dev"
              else
                ssh "$TAILSCALE_HOST" "sgdisk -n 0:0:+$part_size -t 0:8300 -c 0:nixos $disk_dev"
              fi

              # Get the new partition device name
              part_num=$(ssh "$TAILSCALE_HOST" "sgdisk -p $disk_dev 2>/dev/null | tail -1 | awk '{print \$1}'")
              if [ -z "$part_num" ] || [ "$part_num" = "Number" ]; then
                echo ""
                info "Created partition. Listing current partitions:"
                ssh "$TAILSCALE_HOST" "lsblk -o NAME,SIZE,FSTYPE -n $disk_dev"
                echo ""
                printf "Enter the new partition device (e.g., /dev/sda5): "
                read -r nixos_part
              else
                nixos_part="/dev/$part_num"
              fi

              info "Formatting $nixos_part as ext4 (label: nixos) ..."
              ssh "$TAILSCALE_HOST" "mkfs.ext4 -L nixos $nixos_part" >/dev/null 2>&1
              ok "Partition $nixos_part created and formatted"

              # Sync so partition table is re-read
              ssh "$TAILSCALE_HOST" "partprobe $disk_dev 2>/dev/null || true"

            else
              echo ""
              warn "No unallocated space detected."
              info "Existing partitions:"
              ssh "$TAILSCALE_HOST" "lsblk -o NAME,SIZE,FSTYPE,LABEL -n $disk_dev"
              echo ""
              printf "Enter existing NixOS partition device (e.g., /dev/sda4): "
              read -r nixos_part
            fi
          else
            nixos_part="/dev/$existing"
          fi

          echo ""
          warn "Your host config ($HOST) may have a hardcoded nixosPartition."
          warn "Ensure configurations/nixos/$HOST/default.nix has:"
          warn "  my.disko.dualBoot.nixosPartition = \"$nixos_part\";"
          echo ""
          printf "Continue deployment? [y/N]: "
          read -r confirmed
          if [[ ! "$confirmed" =~ ^[Yy] ]]; then
            echo "❌ Aborting. Update the config and re-run."
            exit 1
          fi

          echo ""
          ok "Deploying NixOS to $nixos_part (useExisting mode) ..."
          exec nix run "$FLAKE_DIR#deploy" -- "$HOST" "$TAILSCALE_HOST"
        '';
      };
      meta.description = "Interactive deploy wizard: SSH into live ISO, pick/partition disk, install NixOS";
    };
  };
}
