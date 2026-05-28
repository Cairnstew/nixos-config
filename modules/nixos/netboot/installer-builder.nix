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
          # Do NOT depend on network-online.target — netboot-minimal has no
          # network manager to signal it (NetworkManager disabled). Kernel IP
          # autoconfig (ip=dhcp on cmdline) sets up the NIC before userspace.
          after = [ "network.target" ];
          wants = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          # Log to console so boot messages are visible on the target screen
          script = ''
            set -xeu

            # Log everything to the physical console screen
            exec > /dev/tty0 2>&1

            echo ""
            echo "╔══════════════════════════════════════════════════════════╗"
            echo "║     NixOS Auto-Installer — Debug Mode                   ║"
            echo "╚══════════════════════════════════════════════════════════╝"
            echo ""

            # Wait for kernel IP autoconfig (ip=dhcp) to complete
            sleep 10

            echo "[DEBUG] Kernel cmdline: $(cat /proc/cmdline)"
            echo ""
            echo "[DEBUG] Network interfaces:"
            ip addr show 2>/dev/null || echo "  (ip command not available)"
            echo ""
            echo "[DEBUG] Route:"
            ip route show 2>/dev/null || true
            echo ""

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

            echo "[DEBUG] SERVER=$SERVER MAC=$MAC STAGE=$STAGE"
            echo ""

            if [ -z "$SERVER" ] || [ -z "$MAC" ]; then
              echo "[FAIL] Missing pxe.server or pxe.mac kernel parameters"
              echo "[FAIL] Kernel cmdline: $CMDLINE"
              echo "[FAIL] Sleeping 60s so you can read this — then rebooting..."
              sleep 60
              reboot
            fi

            # ── Discover stage: interactive disk/hostname selection ──
            if [ "$STAGE" = "discover" ]; then
              echo ""
              echo "Available disks:"
              lsblk -dno NAME,SIZE,MODEL,TYPE 2>/dev/null | grep disk || lsblk -d 2>/dev/null || echo "(no lsblk)"
              echo ""

              DEFAULT_DISK="/dev/nvme0n1"
              read -p "Target disk [$DEFAULT_DISK]: " DISK_CHOICE
              DISK_CHOICE=''${DISK_CHOICE:-$DEFAULT_DISK}

              read -p "Windows partition size [150G]: " WIN_SIZE
              WIN_SIZE=''${WIN_SIZE:-150G}

              read -p "Hostname [desktop]: " HOSTNAME
              HOSTNAME=''${HOSTNAME:-desktop}

              echo "Sending config to PXE server $SERVER..."
              ${pkgs.curl}/bin/curl -sS -X POST "http://$SERVER:8888" \
                -H "Content-Type: application/json" \
                -d "{\"mac\":\"$MAC\",\"disk\":\"$DISK_CHOICE\",\"hostname\":\"$HOSTNAME\",\"windowsSize\":\"$WIN_SIZE\"}" \
                --retry 3 --retry-delay 2 || {
                echo "[WARN] Failed to reach PXE server at $SERVER:8888"
              }
              echo "On the PXE server, run: sudo netboot-advance advance $MAC"
              echo "Rebooting in 10 seconds..."
              sleep 10
              reboot
            fi

            # ── Install stage: auto-install with fetched config ──
            echo ""
            echo "=== NixOS Auto-Installer ==="
            echo "Server: $SERVER"
            echo "MAC: $MAC"
            echo ""

            CONFIG_URL="http://$SERVER/machines/$MAC/config.tar.gz"
            CONFIG_DIR="/etc/auto-install"

            echo "[STEP] Fetching config bundle from $CONFIG_URL..."
            mkdir -p "$CONFIG_DIR"
            ${pkgs.curl}/bin/curl -v --connect-timeout 10 --retry 3 --retry-delay 3 \
              -o "$CONFIG_DIR/config.tar.gz" "$CONFIG_URL" 2>&1 || {
                echo "[FAIL] curl exit code $?"
                echo "[FAIL] Could not fetch config bundle — sleeping 60s"
                sleep 60
                reboot
            }
            echo "[OK] Downloaded $(du -h "$CONFIG_DIR/config.tar.gz" | cut -f1)"
            echo ""

            echo "[STEP] Extracting config bundle..."
            tar xzf "$CONFIG_DIR/config.tar.gz" -C "$CONFIG_DIR"
            ls -la "$CONFIG_DIR/"
            echo ""

            if [ -f "$CONFIG_DIR/disko.nix" ]; then
              echo "[STEP] Partitioning with disko..."
              cat "$CONFIG_DIR/disko.nix" 2>/dev/null || true
              echo ""
              ${pkgs.disko}/bin/disko --mode disko "$CONFIG_DIR/disko.nix" || {
                echo "[FAIL] disko failed — sleeping 60s"
                sleep 60
                reboot
              }
              echo "[OK] Disko partitioning complete"
              echo ""

              echo "[STEP] Mounting partitions..."
              ${pkgs.disko}/bin/disko --mode mount "$CONFIG_DIR/disko.nix" 2>&1 || {
                echo "[WARN] mount failed — continuing anyway"
              }
            else
              echo "[WARN] No disko.nix found — skipping partitioning"
            fi

            if [ -f "$CONFIG_DIR/configuration.nix" ]; then
              echo "[STEP] Running nixos-install..."
              cat "$CONFIG_DIR/configuration.nix" 2>/dev/null || true
              echo ""
              mkdir -p /mnt/etc/nixos
              cp "$CONFIG_DIR/configuration.nix" /mnt/etc/nixos/configuration.nix
              nixos-install --root /mnt --no-root-passwd --keep-going 2>&1 || {
                echo "[FAIL] nixos-install failed — sleeping 60s"
                sleep 60
                reboot
              }
              echo "[OK] nixos-install complete"
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
        # Set root password so we can SSH in for debugging
        users.users.root.password = "nixos123";
        environment.systemPackages = with pkgs; [ disko curl ];
      }
    ];
  };
in
rec {
  inherit (eval.config.system.build) kernel netbootRamdisk;
}
