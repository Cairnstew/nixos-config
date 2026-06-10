{ config, lib, pkgs, ... }:
let
  cfg = config.my.disko.dualBoot;
  inherit (lib) mkIf mkDefault mkForce;
  isExisting = cfg.mode == "useExisting";
  isFresh = cfg.mode == "fresh";
in
mkIf cfg.enable {

  # ── disko.devices (mode-dependent) ────────────────────────
  # Single definition — the disko option type rejects duplicate definitions
  # even when gated behind mkIf. Use a Nix if-else to choose at eval time.
  disko.devices.disk.main =
    if isFresh then {
      type = "disk";
      device = mkDefault cfg.disk;
      # Layout: ESP → MSR → Windows → NixOS → [reserved free space]
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "${toString cfg.espSizeGB}G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          msr = {
            size = "${toString cfg.msrSizeMB}M";
            type = "E3C9E316-31B4-4298-89FA-94C9F823F8A5";
          };
          windows = {
            size = "${toString cfg.windowsSizeGB}G";
            type = "0700";
            label = "Windows";
          };
          nixos = {
            size =
              if cfg.nixosSizeGB != null then "${toString cfg.nixosSizeGB}G"
              else "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    } else if isExisting then {
      type = "disk";
      device = cfg.disk;
      # All four partitions declared to match physical layout and get correct
      # sgdisk indexes (1=ESP, 2=MSR, 3=Windows, 4=NixOS). The first three
      # use content = null to skip format/mount. Only nixos gets formatted.
      # Deploy with --disko-mode disko (auto-detected) so sgdisk creates sdb4
      # if missing (format mode skips create, which would fail).
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          msr = {
            size = "16M";
            type = "E3C9E316-31B4-4298-89FA-94C9F823F8A5";
            content = null;
          };
          windows = {
            size = "80G";
            type = "0700";
            content = null;
          };
          nixos = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    } else { };

  assertions = [
    {
      assertion = !(cfg.enable && isFresh && cfg.reservedSizeGB > 0 && cfg.nixosSizeGB == null);
      message = "my.disko.dualBoot.nixosSizeGB is required when reservedSizeGB > 0.";
    }
    {
      assertion = !(cfg.enable && isExisting && cfg.espPartition == null);
      message = "my.disko.dualBoot.espPartition must be set when mode = \"useExisting\". "
        + "Example: espPartition = \"/dev/disk/by-partlabel/disk-main-ESP\";";
    }
    {
      assertion = !(cfg.enable && isExisting && cfg.nixosPartition == null);
      message = "my.disko.dualBoot.nixosPartition must be set when mode = \"useExisting\".";
    }
  ];

  fileSystems."/" = mkIf isExisting (mkForce {
    device = cfg.nixosPartition;
    fsType = "ext4";
  });

  fileSystems."/boot" = mkIf isExisting (mkForce {
    device = cfg.espPartition;
    fsType = "vfat";
    options = [ "umask=0077" ];
  });

  # ── Bootloader ────────────────────────────────────────────
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.efiSupport = true;
  boot.loader.efi.canTouchEfiVariables = mkDefault (!config.boot.loader.grub.efiInstallAsRemovable);
  boot.loader.grub.useOSProber = cfg.useOSProber;

  boot.loader.grub.extraEntries = mkDefault ''
    menuentry "Windows 11" {
      insmod part_gpt
      insmod fat
      insmod chain
      search --no-floppy --label --set=root ESP
      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
  '';

  # ── Windows post-install: restore GRUB EFI boot order ──
  # Windows Setup always sets itself as the first EFI boot entry.
  # This oneshot service runs once after first boot to repair the order
  # so GRUB comes before Windows Boot Manager.
  systemd.services.windows-post-install = {
    description = "Restore GRUB EFI boot order after Windows install";
    after = [ "boot-complete.target" ];
    wants = [ "boot-complete.target" ];

    path = [ pkgs.efibootmgr ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "windows-post-install";
    };

    script = ''
      set -euo pipefail

      STAMP="/var/lib/windows-post-install/.done"
      if [ -f "$STAMP" ]; then
        exit 0
      fi
      mkdir -p "$(dirname "$STAMP")"

      echo "[windows-post-install] Checking EFI boot order..."
      BOOTMGR="$(efibootmgr -v 2>/dev/null || true)"
      echo "$BOOTMGR"

      CURRENT_ORDER=$(echo "$BOOTMGR" | grep "^BootOrder:" | sed 's/^BootOrder: //')

      NIXOS_ID=$(echo "$BOOTMGR" | grep -i "NixOS\|GRUB" | grep "^Boot[0-9a-fA-F]\{4\}" | sed 's/^Boot\([0-9a-fA-F]\{4\}\).*/\1/' | head -1)
      WIN_ID=$(echo "$BOOTMGR" | grep -i "Windows Boot Manager" | grep "^Boot[0-9a-fA-F]\{4\}" | sed 's/^Boot\([0-9a-fA-F]\{4\}\).*/\1/' | head -1)

      # Remove stale "Windows 11 Setup" entries from installer ISO
      STALE=$(echo "$BOOTMGR" | grep -i "Windows 11 Setup" | grep "^Boot[0-9a-fA-F]\{4\}" | sed 's/^Boot\([0-9a-fA-F]\{4\}\).*/\1/')
      for entry in $STALE; do
        echo "[windows-post-install] Removing stale entry Boot$entry..."
        efibootmgr -b "$entry" -B 2>/dev/null || true
      done

      if [ -n "$NIXOS_ID" ] && [ -n "$WIN_ID" ]; then
        NEW_ORDER="$NIXOS_ID"
        for entry in $(echo "$CURRENT_ORDER" | tr ',' ' '); do
          if [ "$entry" != "$NIXOS_ID" ]; then
            NEW_ORDER="$NEW_ORDER,$entry"
          fi
        done
        echo "[windows-post-install] Setting boot order: $NEW_ORDER"
        efibootmgr -o "$NEW_ORDER" 2>/dev/null || true
        echo "[windows-post-install] Boot order repaired."
      else
        echo "[windows-post-install] Could not find NixOS entry ($NIXOS_ID) or Windows entry ($WIN_ID) — skipping"
      fi

      touch "$STAMP"
      echo "[windows-post-install] Complete."
    '';
  };
}
