{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.windowsInstaller;
  inherit (lib) mkIf;

  # Get the packages from flake inputs
  uup-builder = flake.inputs.uup-builder.packages.${pkgs.system}.default or flake.inputs.uup-builder.defaultPackage.${pkgs.system};
  generateAnswerFile = flake.inputs.generate-answer-file.packages.${pkgs.system}.default or flake.inputs.generate-answer-file.defaultPackage.${pkgs.system};
in
mkIf cfg.enable {
  systemd.services.windows-installer = {
    description = "Automated Windows 11 installer on first boot";

    # Run once, only if not already done
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    # Only run if the .done file doesn't exist
    unitConfig = {
      ConditionPathExists = "!/var/lib/windows-installer/.done";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      # Required packages for the installation script
      path = [
        uup-builder
        generateAnswerFile
        pkgs.efibootmgr
        pkgs.cdrkit  # provides genisoimage
        pkgs.util-linux
        pkgs.coreutils
        pkgs.curl
        pkgs.gnutar
        pkgs.gzip
        pkgs.mount
      ];
    };

    script = ''
      set -euo pipefail

      echo "=== Windows Installer Starting ==="
      
      # Create output directory
      mkdir -p "${cfg.isoOutputDir}"
      cd "${cfg.isoOutputDir}"

      # Step 1: Download and build Windows ISO using uup-builder
      echo "[1/5] Downloading Windows ${cfg.windowsBuild} ${cfg.windowsEdition}..."
      uup-builder build \
        --search "${cfg.windowsBuild}" \
        --lang "${cfg.windowsLang}" \
        --edition "${cfg.windowsEdition}" \
        --out "${cfg.isoOutputDir}"

      # Find the generated ISO
      ISO_FILE=$(ls -t "${cfg.isoOutputDir}"/*.iso 2>/dev/null | head -n1)
      if [ -z "$ISO_FILE" ]; then
        echo "ERROR: No ISO file found in ${cfg.isoOutputDir}"
        exit 1
      fi
      echo "ISO created: $ISO_FILE"

      # Step 2: Generate autounattend.xml answer file
      echo "[2/5] Generating autounattend.xml answer file..."
      
      # Handle local account - if empty, use default
      LOCAL_ACCOUNT="${cfg.localAccount}"
      if [ -z "$LOCAL_ACCOUNT" ]; then
        echo "WARNING: No local account configured. Windows will require manual setup."
        echo "Set my.services.windowsInstaller.localAccount via agenix or config.nix"
        LOCAL_ACCOUNT_ARG=""
      else
        LOCAL_ACCOUNT_ARG="-LocalAccount '$LOCAL_ACCOUNT'"
      fi

      GenerateAnswerFile \
        -Install ExistingPartition \
        -InstallToDisk 0 \
        -InstallToPartition ${toString cfg.windowsPartitionIndex} \
        -TimeZone "${cfg.timeZone}" \
        $LOCAL_ACCOUNT_ARG \
        -OutFile "${cfg.isoOutputDir}/autounattend.xml"

      echo "Answer file generated: ${cfg.isoOutputDir}/autounattend.xml"

      # Step 3: Mount ISO and inject answer file
      echo "[3/5] Injecting answer file into ISO..."
      
      MOUNT_DIR="${cfg.isoOutputDir}/iso-mount"
      mkdir -p "$MOUNT_DIR"
      
      # Mount the ISO
      mount -o loop,ro "$ISO_FILE" "$MOUNT_DIR"
      
      # Create new ISO with answer file injected
      MODIFIED_ISO="${cfg.isoOutputDir}/windows-autounattend.iso"
      
      # Copy ISO contents and add answer file
      WORK_DIR="${cfg.isoOutputDir}/iso-work"
      rm -rf "$WORK_DIR"
      mkdir -p "$WORK_DIR"
      
      echo "Copying ISO contents..."
      cp -r "$MOUNT_DIR"/* "$WORK_DIR/" 2>/dev/null || true
      
      # Unmount original ISO
      umount "$MOUNT_DIR"
      rmdir "$MOUNT_DIR"
      
      # Copy autounattend.xml to ISO root
      cp "${cfg.isoOutputDir}/autounattend.xml" "$WORK_DIR/"
      
      # Create bootable ISO with genisoimage
      echo "Creating modified ISO..."
      genisoimage \
        -o "$MODIFIED_ISO" \
        -b boot/etfsboot.com \
        -no-emul-boot \
        -boot-load-size 8 \
        -boot-info-table \
        -iso-level 2 \
        -J \
        -R \
        -V "WIN11_AUTO" \
        "$WORK_DIR"

      # Cleanup work directory
      rm -rf "$WORK_DIR"
      
      echo "Modified ISO created: $MODIFIED_ISO"

      # Step 4: Set up one-time boot entry for Windows Setup
      echo "[4/5] Setting up one-time EFI boot entry..."
      
      # Mount the ESP to access EFI files
      ESP_MOUNT="${cfg.isoOutputDir}/esp-mount"
      mkdir -p "$ESP_MOUNT"
      mount /dev/disk/by-partlabel/ESP "$ESP_MOUNT" 2>/dev/null || mount /boot "$ESP_MOUNT"
      
      # Extract boot files from ISO to ESP
      WINDOWS_EFI_DIR="$ESP_MOUNT/EFI/Microsoft/Boot"
      mkdir -p "$WINDOWS_EFI_DIR"
      
      # Mount the modified ISO to copy boot files
      mkdir -p "$MOUNT_DIR"
      mount -o loop,ro "$MODIFIED_ISO" "$MOUNT_DIR"
      
      # Copy Windows setup EFI files
      if [ -d "$MOUNT_DIR/efi/microsoft" ]; then
        cp -r "$MOUNT_DIR/efi/microsoft"/* "$WINDOWS_EFI_DIR/" 2>/dev/null || true
      fi
      
      # Also copy bootmgr.efi if present
      if [ -f "$MOUNT_DIR/efi/boot/bootx64.efi" ]; then
        cp "$MOUNT_DIR/efi/boot/bootx64.efi" "$ESP_MOUNT/EFI/Boot/bootx64.efi.windows" 2>/dev/null || true
      fi
      
      umount "$MOUNT_DIR"
      rmdir "$MOUNT_DIR"
      
      # Set up one-time boot entry using efibootmgr
      # First, find the Windows setup EFI file
      if [ -f "$WINDOWS_EFI_DIR/bootmgfw.efi" ]; then
        echo "Creating EFI boot entry for Windows Setup..."
        
        # Get the disk and partition for ESP
        ESP_PARTITION=$(df "$ESP_MOUNT" | tail -1 | awk '{print $1}')
        
        # Create boot entry (will be one-time via --bootnext)
        efibootmgr --create \
          --disk "${cfg.windowsDisk}" \
          --part 1 \
          --label "Windows 11 Setup" \
          --loader '\\EFI\\Microsoft\\Boot\\bootmgfw.efi' \
          --verbose || echo "Boot entry creation may have failed, continuing..."
        
        # Set as next boot (one-time)
        BOOT_NUM=$(efibootmgr | grep "Windows 11 Setup" | head -1 | sed 's/Boot\([0-9A-Fa-f]*\).*/\1/')
        if [ -n "$BOOT_NUM" ]; then
          efibootmgr --bootnext "$BOOT_NUM"
          echo "Set Windows 11 Setup as next boot (one-time)"
        fi
      fi
      
      # Unmount ESP
      umount "$ESP_MOUNT"
      rmdir "$ESP_MOUNT"

      # Step 5: Mark as done and reboot
      echo "[5/5] Installation prepared successfully!"
      
      # Create .done file to prevent re-running
      touch "${cfg.isoOutputDir}/.done"
      
      echo ""
      echo "=================================================="
      echo "Windows installation prepared!"
      echo "System will reboot in 10 seconds..."
      echo "=================================================="
      
      sleep 10
      systemctl reboot
    '';

    # Ensure the service can write to the output directory
    environment = {
      # Any environment variables needed by the tools
    };
  };

  # Create the output directory with proper permissions
  systemd.tmpfiles.rules = [
    "d ${cfg.isoOutputDir} 0755 root root -"
  ];
}
