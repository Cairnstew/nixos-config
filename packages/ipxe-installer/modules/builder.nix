# netboot installer builder — custom NixOS netboot kernel + initrd for auto-installation
{ pkgs, system ? pkgs.stdenv.hostPlatform.system }:

let
  eval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
    inherit system;
    modules = [
      "${pkgs.path}/nixos/modules/installer/netboot/netboot.nix"
      "${pkgs.path}/nixos/modules/installer/netboot/netboot-minimal.nix"
      {
        systemd.services.nixos-auto-install = {
          description = "NixOS Automatic Installer";
          after = [ "network.target" ];
          wants = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            set -xeu
            exec > /dev/tty0 2>&1

            echo ""
            echo "╔══════════════════════════════════════════════════════════╗"
            echo "║     NixOS Auto-Installer                                ║"
            echo "╚══════════════════════════════════════════════════════════╝"
            echo ""

            sleep 10
            echo "[DEBUG] Kernel cmdline: $(cat /proc/cmdline)"
            echo ""

            CMDLINE=$(cat /proc/cmdline)
            SERVER=""
            MAC=""
            for kv in $CMDLINE; do
              case "$kv" in
                pxe.server=*) SERVER="''${kv#pxe.server=}" ;;
                pxe.mac=*)    MAC="''${kv#pxe.mac=}" ;;
              esac
            done

            if [ -z "$SERVER" ] || [ -z "$MAC" ]; then
              echo "[FAIL] Missing pxe.server or pxe.mac — sleeping 60s"
              sleep 60
              reboot
            fi

            echo "[DEBUG] SERVER=$SERVER MAC=$MAC"
            echo "[DEBUG] Network:"
            ip addr show 2>/dev/null || echo "(no ip)"
            ip route show 2>/dev/null || true
            echo ""

            CONFIG_URL="http://$SERVER/machines/$MAC/config.tar.gz"
            CONFIG_DIR="/etc/auto-install"

            echo "[STEP] Fetching $CONFIG_URL..."
            mkdir -p "$CONFIG_DIR"
            ${pkgs.curl}/bin/curl -v --connect-timeout 10 --retry 3 --retry-delay 3 \
              -o "$CONFIG_DIR/config.tar.gz" "$CONFIG_URL" 2>&1 || {
                echo "[FAIL] curl failed — sleeping 60s"
                sleep 60
                reboot
            }

            echo "[STEP] Extracting..."
            tar xzf "$CONFIG_DIR/config.tar.gz" -C "$CONFIG_DIR"

            if [ -f "$CONFIG_DIR/disko.nix" ]; then
              echo "[STEP] Partitioning with disko..."
              ${pkgs.disko}/bin/disko --mode disko "$CONFIG_DIR/disko.nix" || {
                echo "[FAIL] disko failed — sleeping 60s"
                sleep 60
                reboot
              }
              ${pkgs.disko}/bin/disko --mode mount "$CONFIG_DIR/disko.nix" 2>&1 || true
            fi

            if [ -f "$CONFIG_DIR/configuration.nix" ]; then
              echo "[STEP] Running nixos-install..."
              mkdir -p /mnt/etc/nixos
              cp "$CONFIG_DIR/configuration.nix" /mnt/etc/nixos/configuration.nix
              nixos-install --root /mnt --no-root-passwd --keep-going 2>&1 || {
                echo "[FAIL] nixos-install failed — sleeping 60s"
                sleep 60
                reboot
              }
            fi

            echo "=== Installation complete ==="
            nixos-enter --root /mnt --command "grub-mkconfig -o /boot/grub/grub.cfg" 2>/dev/null || true
            echo "Rebooting..."
            sleep 5
            reboot
          '';
        };

        services.openssh.enable = true;
        users.users.root.password = "nixos123";
        environment.systemPackages = with pkgs; [ disko curl ];
      }
    ];
  };
in
rec {
  inherit (eval.config.system.build) kernel netbootRamdisk;
}
