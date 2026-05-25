{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.windowsPostInstall;
  inherit (lib) mkIf;
in
mkIf cfg.enable {
  systemd.services.windows-post-install = {
    description = "Restore GRUB as default EFI boot entry after Windows install";

    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];

    unitConfig = {
      ConditionPathExists = "!/var/lib/windows-post-install/.done";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      path = [ pkgs.efibootmgr pkgs.coreutils pkgs.gnused ];
    };

    script = ''
      set -euo pipefail

      echo "=== Windows Post-Install: Checking EFI boot order ==="

      WINDOWS_EFI="/boot/EFI/Microsoft/Boot/bootmgfw.efi"

      if [ ! -f "$WINDOWS_EFI" ]; then
        echo "Windows EFI files not found — nothing to do."
        mkdir -p /var/lib/windows-post-install
        touch /var/lib/windows-post-install/.done
        exit 0
      fi

      echo "Windows EFI files detected."

      # ── Restore GRUB as default EFI boot entry ──────────────────────────
      if [ "${toString cfg.autoFixBootOrder}" = "true" ]; then
        echo "Checking EFI boot order..."

        GRUB_ENTRY=$(efibootmgr | grep -i "grub" | head -1)
        GRUB_NUM=$(echo "$GRUB_ENTRY" | sed 's/Boot\([0-9A-Fa-f]*\).*/\1/')

        if [ -n "$GRUB_NUM" ]; then
          CURRENT_BOOT_ORDER=$(efibootmgr | grep "^BootOrder:" | sed 's/^BootOrder: //')
          echo "Current boot order: $CURRENT_BOOT_ORDER"
          echo "GRUB entry number: $GRUB_NUM"

          if echo "$CURRENT_BOOT_ORDER" | grep -qi "^$GRUB_NUM" 2>/dev/null; then
            echo "GRUB is already first in boot order — no change needed."
          else
            # Move GRUB to the front of the boot order
            NEW_ORDER="$GRUB_NUM"
            for e in $(echo "$CURRENT_BOOT_ORDER" | tr ',' ' '); do
              if [ "$e" != "$GRUB_NUM" ]; then
                NEW_ORDER="$NEW_ORDER,$e"
              fi
            done
            efibootmgr --bootorder "$NEW_ORDER" 2>/dev/null || true
            echo "Boot order restored: GRUB ($GRUB_NUM) moved to front."
          fi
        else
          echo "WARNING: GRUB EFI entry not found in efibootmgr output."
          echo "Attempting to add GRUB entry..."
          efibootmgr --create \
            --disk ${config.my.disko.dualBoot.disk or "/dev/nvme0n1"} \
            --part 1 \
            --label "GRUB" \
            --loader '\\EFI\\grub\\grubx64.efi' \
            --verbose 2>/dev/null || echo "Could not create GRUB entry."
        fi

        # ── Clean up stale "Windows 11 Setup" entry ────────────────────────
        efibootmgr | grep "Windows 11 Setup" | while read -r line; do
          entry_num=$(echo "$line" | sed 's/Boot\([0-9A-Fa-f]*\).*/\1/')
          if [ -n "$entry_num" ]; then
            efibootmgr -b "$entry_num" -B 2>/dev/null || true
            echo "Removed stale Windows 11 Setup EFI entry ($entry_num)."
          fi
        done
      fi

      echo ""
      echo "=== Windows post-install checks complete ==="

      mkdir -p /var/lib/windows-post-install
      touch /var/lib/windows-post-install/.done
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/windows-post-install 0755 root root -"
  ];
}
