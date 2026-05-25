{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.windowsDscSync;
  inherit (lib) mkIf;
in
mkIf cfg.enable {
  systemd = {
    # One-shot service that mounts Windows, copies DSC config, unmounts
    services.windows-dsc-sync = {
      description = "Sync DSC YAML config to Windows partition";
      wantedBy = [ "windows-dsc-sync.path" ];
      partOf = [ "windows-dsc-sync.path" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        path = [ pkgs.ntfs3g pkgs.coreutils pkgs.findutils pkgs.jq ];
      };

      script = ''
        set -euo pipefail

        DSC_SRC="${config.my.services.dscnix.configFile or "/etc/dscnix/desktop.yaml"}"
        WINDOWS_PART="${cfg.windowsPartition}"
        MOUNT_POINT="${cfg.mountPoint}"
        TARGET_DIR="$MOUNT_POINT/${cfg.windowsTargetDir}"

        echo "=== windows-dsc-sync: Checking Windows partition ==="

        if [ ! -b "$WINDOWS_PART" ]; then
          echo "Windows partition $WINDOWS_PART not found — skipping."
          exit 0
        fi

        if [ ! -f "$DSC_SRC" ]; then
          echo "DSC config $DSC_SRC not found — skipping."
          exit 0
        fi

        echo "Mounting $WINDOWS_PART to $MOUNT_POINT..."
        mkdir -p "$MOUNT_POINT"
        mount -t ntfs-3g "$WINDOWS_PART" "$MOUNT_POINT" 2>/dev/null || {
          echo "WARNING: Failed to mount $WINDOWS_PART. Is Windows hibernated or fast-boot enabled?"
          echo "Attempting read-only mount..."
          mount -t ntfs-3g -o ro "$WINDOWS_PART" "$MOUNT_POINT" 2>/dev/null || {
            echo "ERROR: Cannot mount Windows partition. Skipping sync."
            exit 0
          }
        }

        echo "Creating target directory $TARGET_DIR..."
        mkdir -p "$TARGET_DIR"

        echo "Copying DSC config..."
        cp "$DSC_SRC" "$TARGET_DIR/dsc-configuration.yaml"
        echo "Written: $TARGET_DIR/dsc-configuration.yaml"

        # Also write the apply-dsc.ps1 bootstrap script if it doesn't exist
        APPLY_PS="$TARGET_DIR/apply-dsc.ps1"
        if [ ! -f "$APPLY_PS" ]; then
          echo "Writing bootstrap script to $APPLY_PS..."
          cat > "$APPLY_PS" << 'PSEOF'
        <#
        .SYNOPSIS
            Apply DSC v3 configuration from NixOS-synced YAML.
            Runs as a scheduled task on Windows boot.
        #>
        param(
            [string]$ConfigPath = "C:\NixOS\dsc-configuration.yaml",
            [string]$StateFile = "C:\NixOS\.dsc-applied-state.json",
            [string]$LogFile = "C:\NixOS\dsc-apply.log"
        )

        $ErrorActionPreference = "Continue"

        function Write-Log { param([string]$Msg) $Msg | Out-File -FilePath $LogFile -Append -Encoding UTF8 }

        Write-Log "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] DSC-Apply starting..."

        if (-not (Test-Path $ConfigPath)) {
            Write-Log "Config not found at $ConfigPath — skipping."
            exit 0
        }

        # Hash-based change detection
        $currentHash = (Get-FileHash $ConfigPath -Algorithm SHA256).Hash
        $lastHash = if (Test-Path $StateFile) {
            try { (Get-Content $StateFile -Raw | ConvertFrom-Json).hash } catch { "" }
        } else { "" }

        if ($currentHash -eq $lastHash) {
            Write-Log "DSC config unchanged (hash: $currentHash) — skipping apply."
            exit 0
        }

        Write-Log "DSC config changed (old: $lastHash, new: $currentHash). Applying..."

        # Check if dsc.exe is available
        $dsc = Get-Command "dsc.exe" -ErrorAction SilentlyContinue
        if (-not $dsc) {
            Write-Log "WARNING: dsc.exe not found. Attempting to install DSC v3..."
            try {
                winget install --id Microsoft.DSC --accept-source-agreements --accept-package-agreements --silent
                $dsc = Get-Command "dsc.exe" -ErrorAction SilentlyContinue
            } catch {
                Write-Log "ERROR: Failed to install DSC v3: $_"
            }
        }

        if ($dsc) {
            & $dsc.Source config set --file $ConfigPath 2>&1 | ForEach-Object { Write-Log "DSC: $_" }
            Write-Log "DSC apply completed with exit code $LASTEXITCODE."

            # Update state file
            @{ hash = $currentHash; timestamp = (Get-Date -Format 'o') } | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
            Write-Log "State file updated at $StateFile"
        } else {
            Write-Log "ERROR: dsc.exe still not available after install attempt."
        }

        Write-Log "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] DSC-Apply finished."
      PSEOF
          echo "Bootstrap script written."
        fi

        # Clean up old state file if config changed (force re-apply on next Windows boot)
        STATE_FILE="$TARGET_DIR/.dsc-applied-state.json"
        if [ -f "$STATE_FILE" ]; then
            OLD_HASH=$(jq -r '.hash' "$STATE_FILE" 2>/dev/null || echo "")
            NEW_HASH=$(sha256sum "$DSC_SRC" | cut -d' ' -f1)
            if [ "$OLD_HASH" != "$NEW_HASH" ]; then
                echo "Config changed (old: $OLD_HASH, new: $NEW_HASH) — clearing state to force re-apply."
                rm -f "$STATE_FILE"
            fi
        fi

        umount "$MOUNT_POINT" 2>/dev/null || true
        rmdir "$MOUNT_POINT" 2>/dev/null || true

        echo "=== windows-dsc-sync: Done ==="
      '';
    };

    # Path unit — triggers the service when the DSC config file changes
    paths.windows-dsc-sync = {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = "/etc/dscnix/desktop.yaml";
        Unit = "windows-dsc-sync.service";
      };
    };
  };
}
