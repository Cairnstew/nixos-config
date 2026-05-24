{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.services.windowsInstaller;
  inherit (lib) mkIf;

  uup-builder = flake.inputs.uup-builder.packages.${pkgs.stdenv.hostPlatform.system}.default or flake.inputs.uup-builder.defaultPackage.${pkgs.stdenv.hostPlatform.system};
in
mkIf cfg.enable {
  systemd.services.windows-installer = {
    description = "Automated Windows 11 installer on first boot";

    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "nss-lookup.target" ];
    wants = [ "network-online.target" ];

    unitConfig = {
      ConditionPathExists = "!/var/lib/windows-installer/.done";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      path = [
        uup-builder
        pkgs.efibootmgr
        pkgs.cdrkit
        pkgs.util-linux
        pkgs.coreutils
        pkgs.curl
        pkgs.gnutar
        pkgs.gzip
      ];
    };

    script = ''
      set -euo pipefail

      echo "=== Windows Installer Starting ==="

      mkdir -p "${cfg.isoOutputDir}"
      cd "${cfg.isoOutputDir}"

      # ── Step 1: Download and build Windows ISO using uup-builder ──────────
      echo "[1/8] Downloading Windows ${cfg.windowsBuild} ${cfg.windowsEdition}..."
      uup-builder build \
        --search "${cfg.windowsBuild}" \
        --lang "${cfg.windowsLang}" \
        --edition "${cfg.windowsEdition}" \
        --out "${cfg.isoOutputDir}"

      ISO_FILE=$(ls -t "${cfg.isoOutputDir}"/*.iso 2>/dev/null | head -n1)
      if [ -z "$ISO_FILE" ]; then
        echo "ERROR: No ISO file found in ${cfg.isoOutputDir}"
        exit 1
      fi
      echo "ISO created: $ISO_FILE"

      # ── Step 2: Mount ISO and extract contents ──────────────────────────
      echo "[2/8] Mounting ISO and extracting contents..."

      MOUNT_DIR="${cfg.isoOutputDir}/iso-mount"
      WORK_DIR="${cfg.isoOutputDir}/iso-work"
      mkdir -p "$MOUNT_DIR"
      rm -rf "$WORK_DIR"

      mount -o loop,ro "$ISO_FILE" "$MOUNT_DIR"

      echo "Copying ISO contents..."
      mkdir -p "$WORK_DIR"
      cp -r "$MOUNT_DIR"/* "$WORK_DIR/" 2>/dev/null || true

      umount "$MOUNT_DIR"
      rmdir "$MOUNT_DIR"

      # ── Step 3: Inject autounattend.xml ─────────────────────────────────
      echo "[3/8] Writing autounattend.xml..."

      cat > "$WORK_DIR/autounattend.xml" << 'XMLEOF'
      <?xml version="1.0" encoding="utf-8"?>
      <unattend xmlns="urn:schemas-microsoft-com:unattend">
          <settings pass="windowsPE">
              <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                  <SetupUILanguage>
                      <UILanguage>en-GB</UILanguage>
                  </SetupUILanguage>
                  <InputLocale>0809:00000809</InputLocale>
                  <SystemLocale>en-GB</SystemLocale>
                  <UILanguage>en-GB</UILanguage>
                  <UserLocale>en-GB</UserLocale>
              </component>
              <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                  <DiskConfiguration>
                      <WillShowUI>OnError</WillShowUI>
                  </DiskConfiguration>
                  <ImageInstall>
                      <OSImage>
                          <InstallFrom>
                              <MetaData wcm:action="add">
                                  <Key>/IMAGE/NAME</Key>
                                  <Value>Windows ${cfg.windowsEdition}</Value>
                              </MetaData>
                          </InstallFrom>
                          <InstallTo>
                              <DiskID>0</DiskID>
                              <PartitionID>${toString cfg.windowsPartitionIndex}</PartitionID>
                          </InstallTo>
                      </OSImage>
                  </ImageInstall>
                  <UserData>
                      <ProductKey>
                          <Key></Key>
                          <WillShowUI>Never</WillShowUI>
                      </ProductKey>
                      <AcceptEula>true</AcceptEula>
                  </UserData>
              </component>
          </settings>
          <settings pass="specialize">
              <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                  <RunSynchronous>
                      <RunSynchronousCommand wcm:action="add">
                          <Order>1</Order>
                          <Path>reg.exe add "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f</Path>
                      </RunSynchronousCommand>
                  </RunSynchronous>
              </component>
              <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                  <TimeZone>${cfg.timeZone}</TimeZone>
                  <ComputerName>*</ComputerName>
              </component>
          </settings>
          <settings pass="oobeSystem">
              <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                  <OOBE>
                      <HideEULAPage>true</HideEULAPage>
                      <HideLocalAccountScreen>false</HideLocalAccountScreen>
                      <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                      <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                      <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                      <NetworkLocation>Home</NetworkLocation>
                      <ProtectYourPC>3</ProtectYourPC>
                      <SkipMachineOOBE>true</SkipMachineOOBE>
                      <SkipUserOOBE>true</SkipUserOOBE>
                  </OOBE>
                  <UserAccounts>
                      <LocalAccounts>
                          <LocalAccount wcm:action="add">
                              <Name>${cfg.localUsername}</Name>
                              <Group>Administrators</Group>
                              <Password>
                                  <Value>${cfg.localPassword}</Value>
                                  <PlainText>true</PlainText>
                              </Password>
                          </LocalAccount>
                      </LocalAccounts>
                  </UserAccounts>
                  <AutoLogon>
                      <Enabled>true</Enabled>
                      <LogonCount>1</LogonCount>
                      <Username>${cfg.localUsername}</Username>
                      <Password>
                          <Value>${cfg.localPassword}</Value>
                          <PlainText>true</PlainText>
                      </Password>
                  </AutoLogon>
                  <FirstLogonCommands>
                      <SynchronousCommand wcm:action="add">
                          <CommandLine>powershell.exe -NoProfile -Command "Get-AppxPackage Microsoft.Teams | Remove-AppxPackage"</CommandLine>
                          <Description>Remove Teams</Description>
                          <Order>1</Order>
                      </SynchronousCommand>
                      <SynchronousCommand wcm:action="add">
                          <CommandLine>powershell.exe -NoProfile -Command "Get-AppxPackage Microsoft.Office.Outlook | Remove-AppxPackage"</CommandLine>
                          <Description>Remove Outlook</Description>
                          <Order>2</Order>
                      </SynchronousCommand>
                      <SynchronousCommand wcm:action="add">
                          <CommandLine>powershell.exe -NoProfile -Command "Get-AppxPackage Microsoft.Copilot | Remove-AppxPackage"</CommandLine>
                          <Description>Remove Copilot</Description>
                          <Order>3</Order>
                      </SynchronousCommand>
                  </FirstLogonCommands>
              </component>
          </settings>
      </unattend>
XMLEOF

      echo "autounattend.xml written"

      # ── Step 4: Inject OEM DSC configuration ─────────────────────────────
      echo "[4/8] Injecting DSC configuration..."
      OEM_DIR="$WORK_DIR/sources/\$OEM\$/\$/\$/Setup/Scripts"
      mkdir -p "$OEM_DIR"
      if [ -n "${cfg.dscConfigPath}" ] && [ -f "${cfg.dscConfigPath}" ]; then
        cp "${cfg.dscConfigPath}" "$OEM_DIR/dsc-configuration.yaml"
        echo "Injected DSC config from ${cfg.dscConfigPath}"
      else
        echo "WARNING: dscConfigPath not set or file not found — skipping DSC injection"
      fi

      # ── Step 5: Repack ISO with genisoimage ─────────────────────────────
      echo "[5/8] Repacking modified ISO..."
      MODIFIED_ISO="${cfg.isoOutputDir}/windows-autounattend.iso"

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

      rm -rf "$WORK_DIR"
      echo "Modified ISO created: $MODIFIED_ISO"

      # ── Step 6: Extract EFI boot files to ESP ──────────────────────────
      echo "[6/8] Extracting EFI boot files to ESP..."

      ESP_MOUNT="${cfg.isoOutputDir}/esp-mount"
      mkdir -p "$ESP_MOUNT"
      mount /dev/disk/by-partlabel/ESP "$ESP_MOUNT" 2>/dev/null || mount /boot "$ESP_MOUNT"

      WINDOWS_EFI_DIR="$ESP_MOUNT/EFI/Microsoft/Boot"
      mkdir -p "$WINDOWS_EFI_DIR"

      mkdir -p "$MOUNT_DIR"
      mount -o loop,ro "$MODIFIED_ISO" "$MOUNT_DIR"

      if [ -d "$MOUNT_DIR/efi/microsoft" ]; then
        cp -r "$MOUNT_DIR/efi/microsoft"/* "$WINDOWS_EFI_DIR/" 2>/dev/null || true
      fi

      if [ -f "$MOUNT_DIR/bootmgr.efi" ]; then
        cp "$MOUNT_DIR/bootmgr.efi" "$ESP_MOUNT/EFI/Microsoft/" 2>/dev/null || true
      fi

      umount "$MOUNT_DIR"
      rmdir "$MOUNT_DIR"

      # ── Step 7: Register EFI boot entry ─────────────────────────────────
      echo "[7/8] Registering one-time EFI boot entry for Windows Setup..."

      if [ -f "$WINDOWS_EFI_DIR/bootmgfw.efi" ]; then
        efibootmgr | grep "Windows 11 Setup" | while read -r line; do
          entry_num=$(echo "$line" | sed 's/Boot\([0-9A-Fa-f]*\).*/\1/')
          if [ -n "$entry_num" ]; then
            efibootmgr -b "$entry_num" -B 2>/dev/null || true
          fi
        done

        efibootmgr --create \
          --disk "${cfg.windowsDisk}" \
          --part 1 \
          --label "Windows 11 Setup" \
          --loader '\\EFI\\Microsoft\\Boot\\bootmgfw.efi' \
          --verbose || echo "Boot entry creation may have failed, continuing..."

        BOOT_NUM=$(efibootmgr | grep "Windows 11 Setup" | head -1 | sed 's/Boot\([0-9A-Fa-f]*\).*/\1/')
        if [ -n "$BOOT_NUM" ]; then
          efibootmgr --bootnext "$BOOT_NUM"
          echo "Set Windows 11 Setup as next boot (one-time, entry $BOOT_NUM)"
        fi
      else
        echo "WARNING: bootmgfw.efi not found — EFI boot entry not created"
        echo "Verify disk/partition flags match target hardware"
      fi

      umount "$ESP_MOUNT"
      rmdir "$ESP_MOUNT"

      # ── Step 8: Mark done and reboot ─────────────────────────────────────
      echo "[8/8] Installation prepared — marking complete and rebooting..."

      touch "${cfg.isoOutputDir}/.done"

      echo ""
      echo "=================================================="
      echo "Windows installation prepared!"
      echo "System will reboot in 10 seconds..."
      echo "=================================================="

      sleep 10
      systemctl reboot
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${cfg.isoOutputDir} 0755 root root -"
  ];
}
