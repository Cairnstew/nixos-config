{ config, lib, ... }: {
  perSystem = { pkgs, system, ... }: let
    inherit (lib) stringAfter;

    # ── Minimal NixOS live ISO (SSH + git + flakes) ────────────────
    minimalEval = import "${pkgs.path}/nixos" {
      configuration = { pkgs, lib, modulesPath, ... }: {
        imports = [
          (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
        ];

        networking.hostName = "minimal";
        nixpkgs.hostPlatform = system;
        system.stateVersion = "24.05";

        # User with password for local access
        users.users.minimal = {
          isNormalUser = true;
          initialPassword = "nixos";
          extraGroups = [ "wheel" ];
        };
        users.users.root.initialPassword = "nixos";
        security.sudo.wheelNeedsPassword = false;

        # SSH for remote access
        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = true;
          settings.PermitRootLogin = "yes";
        };

        # Git + flakes
        programs.git.enable = true;
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        nix.settings.accept-flake-config = true;

        # Auto-clone the flake repo at boot
        systemd.services.clone-nix-config = {
          wantedBy = [ "multi-user.target" ];
          requires = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [ pkgs.git ];
          serviceConfig.Type = "oneshot";
          serviceConfig.User = "minimal";
          script = ''
            if [[ ! -d /home/minimal/nixos-config ]]; then
              git clone https://github.com/Cairnstew/nixos-config.git /home/minimal/nixos-config
            fi
          '';
        };

        isoImage.makeEfiBootable = true;
        isoImage.makeUsbBootable = true;
      };
      inherit system;
    };

    # ── NixOS Installer ISO (same as minimal + setup script) ───────
    # Use this for Ventoy: boot, run `sudo /root/install.sh`, done.
    installerEval = import "${pkgs.path}/nixos" {
      configuration = { pkgs, lib, modulesPath, ... }: {
        imports = [
          (modulesPath + "/installer/cd-dvd/installation-cd-base.nix")
        ];

        networking.hostName = "nixos-installer";
        nixpkgs.hostPlatform = system;
        system.stateVersion = "24.05";

        # Root-only live image (no user secrets baked in)
        users.users.root.initialPassword = "nixos";
        security.sudo.wheelNeedsPassword = false;

        # SSH access
        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = true;
          settings.PermitRootLogin = "yes";
        };

        # Git + flakes
        programs.git.enable = true;
        environment.systemPackages = with pkgs; [ cryptsetup ];
        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        nix.settings.accept-flake-config = true;

        # Setup script — clone repo, generate SSH key, show next steps
        system.activationScripts.installerSetup = stringAfter [ "users" ] ''
          mkdir -p /root
          cp ${dualBootConfig} /root/dual-boot-config.nix
          cat > /root/install.sh << 'INSTALL_EOF'
          #!/usr/bin/env bash
          set -euo pipefail

          REPO="https://github.com/Cairnstew/nixos-config"
          DEST="/root/nixos-config"
          export XDG_CONFIG_HOME="$HOME/.config"

          echo ""
          echo "========================================"
          echo "  NixOS Installer — Setup Environment"
          echo "========================================"
          echo ""

          # ── Clone config repo ──────────────────────────
          if [ ! -d "$DEST" ]; then
            echo "[1/4] Cloning nixos-config..."
            git clone "$REPO" "$DEST"
          else
            echo "[1/4] nixos-config already cloned, pulling latest..."
            git -C "$DEST" pull
          fi

          cd "$DEST"

          # ── Generate SSH key for agenix ────────────────
          if [ ! -f ~/.ssh/id_ed25519 ]; then
            echo ""
            echo "[2/4] Generating SSH key..."
            mkdir -p ~/.ssh
            ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "nixos-installer-$(hostname)"
            echo ""
            echo "  Public key: $(cat ~/.ssh/id_ed25519.pub)"
            echo ""
            echo "  Add this key to secrets/secrets.nix, then run:"
            echo "    agenix --rekey"
          else
            echo "[2/4] SSH key already exists"
          fi

          # ── Select install mode ────────────────────────
          echo ""
          echo "[3/4] Install mode"
          echo ""
          echo "  Which installation mode?"
          echo ""
          echo "  1) NixOS only — full disk, no Windows"
          echo "  2) Dual boot — Windows already installed, use remaining space"
          echo ""
          read -rp "  Choice [1]: " mode
          mode=''${mode:-1}

          if [ "$mode" = "2" ]; then
            echo ""
            echo "========================================"
            echo "  Dual Boot — NixOS + Windows"
            echo "========================================"
            echo ""
            echo "  Available disks:"
            lsblk -d -o NAME,SIZE,MODEL,TRAN | head -10
            echo ""
            read -rp "  Install NixOS on which disk (e.g. nvme0n1, sda): " DISK
            DISK="/dev/$DISK"
            if [ ! -b "$DISK" ]; then
              echo "  Not a block device: $DISK"
              exit 1
            fi

            echo ""
            echo "  Scanning for Windows partitions..."
            WINDOWS_PART=$(lsblk "$DISK" -o NAME,FSTYPE -n -r | grep -i ntfs | head -1 | cut -d' ' -f1)
            if [ -z "$WINDOWS_PART" ]; then
              echo "  No NTFS (Windows) partition found on $DISK"
              echo "  Continuing anyway — GRUB will detect what's there."
            else
              echo "  Found Windows partition: $WINDOWS_PART"
            fi

            echo ""
            echo "  Now we will create partitions for NixOS in the remaining space."
            echo "  This script will:"
            echo "    1. Create an EFI system partition (512MB) — shared with Windows"
            echo "    2. Create a swap partition (8GB)"
            echo "    3. Create a ZFS or ext4 root partition (rest of space)"
            echo "    4. Install NixOS with GRUB (os-prober detects Windows)"
            echo ""
            read -rp "  Proceed with partitioning? (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
              echo "  Aborted."
              exit 0
            fi

            echo ""
            echo "  Creating partitions..."
            # Get last sector
            END=$(parted "$DISK" unit s print free | tail -2 | head -1 | awk '{print $2}')
            SWAP_SIZE="8GiB"
            ROOT_START=""

            # Find the start of free space after existing partitions
            parted "$DISK" unit MiB print free
            echo ""
            echo "  Creating swap at end of disk..."
            parted -s "$DISK" mkpart primary linux-swap -$SWAP_SIZE 100%
            SWAP_PART=''${DISK}$(parted -s "$DISK" print | tail -1 | awk '{print $1}')

            echo "  Creating root partition in remaining free space..."
            parted -s "$DISK" mkpart primary ext4 -$SWAP_SIZE 100%

            # Wait for kernel to see new partitions
            udevadm settle
            sleep 1

            ROOT_PART=''${DISK}$(parted -s "$DISK" print | tail -1 | awk '{print $1}')

            echo "  Formatting root partition..."
            mkfs.ext4 -F "$ROOT_PART"
            echo "  Formatting swap..."
            mkswap "$SWAP_PART"

            echo ""
            echo "  Mounting partitions..."
            SWAP="$SWAP_PART"
            ROOT="$ROOT_PART"

            mkdir -p /mnt
            mount "$ROOT" /mnt
            mkdir -p /mnt/boot
            # Find the EFI system partition
            ESP=$(lsblk "$DISK" -o NAME,FSTYPE -n -r | grep -i vfat | head -1 | cut -d' ' -f1)
            if [ -n "$ESP" ]; then
              ESP="/dev/$ESP"
              mount "$ESP" /mnt/boot
              echo "  Mounted EFI partition: $ESP → /mnt/boot"
            else
              echo "  No EFI partition found! Creating..."
              parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
              parted -s "$DISK" set 1 esp on
              udevadm settle
              sleep 1
              ESP="''${DISK}1"
              mkfs.vfat -F32 "$ESP"
              mount "$ESP" /mnt/boot
            fi

            swapon "$SWAP"

            echo ""
            echo "  Generating minimal NixOS config for dual-boot..."
            PARTUUID=$(blkid -s PARTUUID -o value "$ROOT" | head -1)
            SWAP_UUID=$(blkid -s UUID -o value "$SWAP" | head -1)
            CONFIG="/root/dual-boot-config.nix"
            if [ -f "$CONFIG" ]; then
              mkdir -p /mnt/etc/nixos
              # Substitute placeholders with runtime values
              sed \
                -e "s|@@ROOT_PARTUUID@@|$(blkid -s PARTUUID -o value "$ROOT" | head -1)|g" \
                -e "s|@@ESP_PARTUUID@@|$(blkid -s PARTUUID -o value "$ESP" | head -1)|g" \
                -e "s|@@SWAP_UUID@@|$(blkid -s UUID -o value "$SWAP" | head -1)|g" \
                "$CONFIG" > /mnt/etc/nixos/configuration.nix
              echo "  Configuration written to /mnt/etc/nixos/configuration.nix"
            else
              echo "  WARNING: $CONFIG not found — skipping config generation"
              echo "  You will need to write /mnt/etc/nixos/configuration.nix manually."
            fi

            echo ""
            echo "  Configuration written to /mnt/etc/nixos/configuration.nix"
            echo ""
            echo "  To install, run:"
            echo "    nixos-install"
            echo ""
            echo "  After reboot, GRUB will automatically detect Windows."
            echo ""
            echo "  WARNING: The generated config is minimal. Copy it to your flake"
            echo "  repo later, or edit /mnt/etc/nixos/configuration.nix before installing."
            echo ""

            exec "$SHELL"
          fi

          # ── Show next steps ────────────────────────────
          echo ""
          echo "[4/4] Ready!"
          echo ""
          echo "========================================"
          echo "  Next Steps"
          echo "========================================"
          echo ""
          echo "  List hosts:          nix run .#test list"
          echo "  Test a host:         nix run .#test run (hostname)"
          echo "  Install to disk:     sudo nixos-install --flake .#(hostname)"
          echo "  Remote install:      nix run github:nix-community/nixos-anywhere -- --flake .#(hostname) root@(ip)"
          echo ""
          echo "  Before installing:"
          echo "    - Edit flake.nix      → set hostname in a config or profile"
          echo "    - Update secrets      → agenix --rekey (uses your new SSH key)"
          echo "    - Or skip secrets:    → my.secrets.enable = false; in host config"
          echo ""
          echo "  Re-run this script:  $0"
          echo ""

          exec "$SHELL"
          INSTALL_EOF

          chmod +x /root/install.sh
        '';

        # Prompt to run the script on login
        programs.bash.interactiveShellInit = ''
          if [ -f /root/install.sh ] && [ ! -f /root/.installer-done ]; then
            echo ""
            echo "  ╔══════════════════════════════════════════╗"
            echo "  ║  Run: sudo /root/install.sh              ║"
            echo "  ║  to clone config + generate SSH key      ║"
            echo "  ╚══════════════════════════════════════════╝"
            echo ""
          fi
        '';

        isoImage.isoBaseName = lib.mkForce "nixos-installer";
        isoImage.makeEfiBootable = true;
        isoImage.makeUsbBootable = true;
      };
      inherit system;
    };

    isoImageDir = minimalEval.config.system.build.isoImage;
    # ── Dual-boot config template (written to ISO, fill at runtime) ─
    # Placeholders @@ROOT_PARTUUID@@, @@ESP_PARTUUID@@, @@SWAP_UUID@@
    # are substituted by install.sh at runtime via sed.
    dualBootConfig = pkgs.writeText "dual-boot-config.nix" ''
      { config, pkgs, ... }: {
        imports = [ <nixpkgs/nixos/modules/installer/scan/not-detected.nix> ];

        boot.loader = {
          systemd-boot.enable = false;
          efi.canTouchEfiVariables = true;
          grub = {
            enable = true;
            device = "nodev";
            efiSupport = true;
            useOSProber = true;
            fsIdentifier = "provided";
            configurationLimit = 20;
          };
        };

        boot.initrd.availableKernelModules = [ "ahci" "nvme" "xhci_pci" "usb_storage" "sd_mod" ];
        boot.kernelModules = [ "kvm-amd" "kvm-intel" ];

        fileSystems."/" = {
          device = "/dev/disk/by-partuuid/@@ROOT_PARTUUID@@";
          fsType = "ext4";
        };

        fileSystems."/boot" = {
          device = "/dev/disk/by-partuuid/@@ESP_PARTUUID@@";
          fsType = "vfat";
        };

        swapDevices = [ { device = "/dev/disk/by-uuid/@@SWAP_UUID@@"; } ];

        networking.hostName = "nixos-dual";
        system.stateVersion = "24.11";

        nix.settings.experimental-features = [ "nix-command" "flakes" ];
        services.xserver.enable = false;
      }
    '';

    installerIsoDir = installerEval.config.system.build.isoImage;
  in {
    packages.nixos-minimal = pkgs.runCommandLocal "nixos-minimal.iso" {
      inherit isoImageDir;
    } ''
      cp -L "$isoImageDir"/iso/*.iso "$out"
    '';

    packages.nixos-installer = pkgs.runCommandLocal "nixos-installer.iso" {
      inherit installerIsoDir;
    } ''
      cp -L "$installerIsoDir"/iso/*.iso "$out"
    '';
  };
}
