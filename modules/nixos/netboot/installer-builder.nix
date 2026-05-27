{ pkgs, system ? pkgs.system }:

let
  eval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${pkgs.path}/nixos/modules/installer/netboot/netboot.nix"
      "${pkgs.path}/nixos/modules/installer/netboot/netboot-minimal.nix"
      {
        systemd.services.nixos-auto-install = {
          description = "NixOS Automatic Installer";
          after = [ "network.target" "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            set -euo pipefail

            sleep 5

            CMDLINE=$(cat /proc/cmdline)
            SERVER=""
            MAC=""
            STAGE=""
            for kv in $CMDLINE; do
              case "$kv" in
                pxe.server=*) SERVER="''${kv#pxe.server=}" ;;
                pxe.mac=*)    MAC="''${kv#pxe.mac=}" ;;
                pxe.stage=*)  STAGE="''${kv#pxe.stage=}" ;;
              esac
            done

            if [ -z "$SERVER" ] || [ -z "$MAC" ]; then
              echo "ERROR: Missing pxe.server or pxe.mac kernel parameters"
              echo "Kernel cmdline: $CMDLINE"
              exit 1
            fi

            # ── Discover stage: interactive disk/hostname selection ──
            if [ "$STAGE" = "discover" ]; then
              echo "╔══════════════════════════════════════════════════════════╗"
              echo "║     NixOS Provisioning — Disk & Hostname Setup          ║"
              echo "╚══════════════════════════════════════════════════════════╝"

              echo ""
              echo "Available disks:"
              lsblk -dno NAME,SIZE,MODEL,TYPE 2>/dev/null | grep disk || lsblk -d 2>/dev/null || echo "(no lsblk)"
              echo ""

              # Prompt for target disk
              DEFAULT_DISK="/dev/nvme0n1"
              read -p "Target disk [$DEFAULT_DISK]: " DISK_CHOICE
              DISK_CHOICE=''${DISK_CHOICE:-$DEFAULT_DISK}

              read -p "Windows partition size [150G]: " WIN_SIZE
              WIN_SIZE=''${WIN_SIZE:-150G}

              read -p "Hostname [desktop]: " HOSTNAME
              HOSTNAME=''${HOSTNAME:-desktop}

              echo ""
              echo "Sending config to PXE server $SERVER..."
              ${pkgs.curl}/bin/curl -sS -X POST "http://$SERVER:8888" \
                -H "Content-Type: application/json" \
                -d "{\"mac\":\"$MAC\",\"disk\":\"$DISK_CHOICE\",\"hostname\":\"$HOSTNAME\",\"windowsSize\":\"$WIN_SIZE\"}" \
                --retry 3 --retry-delay 2 || {
                echo "Failed to reach PXE server at $SERVER:8888"
                echo "Make sure the netboot-webhook service is running on the server."
              }

              echo ""
              echo "Config submitted!"
              echo "On the PXE server, run: sudo netboot-advance advance $MAC"
              echo "Then reboot this machine to continue."
              echo "Rebooting in 10 seconds..."
              sleep 10
              reboot
            fi

            # ── Install stage: auto-install with fetched config ──
            echo "=== NixOS Auto-Installer ==="
            echo "Server: $SERVER"
            echo "MAC: $MAC"

            CONFIG_URL="http://$SERVER/machines/$MAC/config.tar.gz"
            CONFIG_DIR="/etc/auto-install"

            echo "Fetching config bundle from $CONFIG_URL..."
            mkdir -p "$CONFIG_DIR"
            ${pkgs.curl}/bin/curl -sS --retry 5 --retry-delay 3 -o "$CONFIG_DIR/config.tar.gz" "$CONFIG_URL" || {
              echo "Failed to fetch config bundle — dropping to shell"
              exit 1
            }

            tar xzf "$CONFIG_DIR/config.tar.gz" -C "$CONFIG_DIR"

            if [ -f "$CONFIG_DIR/disko.nix" ]; then
              echo "=== Creating partitions with disko ==="
              ${pkgs.disko}/bin/disko --mode disko "$CONFIG_DIR/disko.nix" || {
                echo "disko failed — dropping to shell"
                exit 1
              }
            fi

            if [ -f "$CONFIG_DIR/disko.nix" ]; then
              echo "=== Mounting partitions under /mnt ==="
              mkdir -p /mnt
              ${pkgs.disko}/bin/disko --mode mount "$CONFIG_DIR/disko.nix" 2>/dev/null || {
                echo "disko mount failed — partitions may need manual mounting"
              }
            fi

            if [ -f "$CONFIG_DIR/configuration.nix" ]; then
              echo "=== Running nixos-install ==="
              mkdir -p /mnt/etc/nixos
              cp "$CONFIG_DIR/configuration.nix" /mnt/etc/nixos/configuration.nix
              if [ -f "$CONFIG_DIR/hardware-configuration.nix" ]; then
                cp "$CONFIG_DIR/hardware-configuration.nix" /mnt/etc/nixos/hardware-configuration.nix
              fi
              nixos-install --root /mnt --no-root-passwd --keep-going || {
                echo "nixos-install failed — dropping to shell"
                exit 1
              }
            fi

            echo "=== Installation complete ==="
            echo "Setting up GRUB for dual-boot..."
            nixos-enter --root /mnt --command "grub-mkconfig -o /boot/grub/grub.cfg" 2>/dev/null || true

            echo "Rebooting in 5 seconds..."
            sleep 5
            reboot
          '';
        };

        services.openssh.enable = true;
        environment.systemPackages = with pkgs; [ disko curl ];
      }
    ];
  };
in
rec {
  inherit (eval.config.system.build) kernel netbootRamdisk;
}
