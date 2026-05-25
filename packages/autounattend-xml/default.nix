# packages/autounattend-xml/default.nix
# Generates autounattend.xml for unattended Windows install to an existing partition
{ lib
, runCommand
, writeText
, # Partition to install to (1-based). Defaults to 2 (Windows partition).
  windowsPartitionIndex ? 2
, # Local admin username
  localUsername ? "user"
, # Local admin password (plain text — requires Windows local account)
  localPassword ? ""
, # Windows timezone identifier (e.g. "GMT Standard Time")
  timeZone ? "GMT Standard Time"
, # Windows edition string (matched via /IMAGE/NAME)
  windowsEdition ? "Windows 11 Pro"
, # Computer name to set in specialize pass
  computerName ? "WINDOWS-PC"
, # Whether to disable automatic recovery partition creation
  disableRecoveryPartition ? true
, # Path to a DSC v3 YAML config on the OEM scripts volume.
  # The injected file is copied to C:\Windows\Setup\Scripts\ during install.
  # Set null to skip DSC bootstrap entirely.
  dscConfigPath ? null
,
}:

let
  # Inline bootstrap script that installs PS7 + DSC v3 and applies the config.
  dscBootstrapScript = if dscConfigPath == null then null else writeText "apply-dsc.ps1" ''
    <#
    .SYNOPSIS
        Bootstrap DSC v3 apply on first Windows boot.
        Injected via $OEM$ and referenced by autounattend.xml FirstLogonCommands.
    #>
    $ErrorActionPreference = "Continue"
    $logFile = "$env:SystemRoot\Temp\dsc-bootstrap.log"
    Start-Transcript -Path $logFile -Append

    Write-Output "[DSC Bootstrap] Starting..."

    # ── 1. Install PowerShell 7 (if not already present) ────────────────────
    $pwsh = Get-Command "pwsh.exe" -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        Write-Output "[DSC Bootstrap] Installing PowerShell 7..."
        $msiUrl = "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi"
        $msiPath = "$env:TEMP\PowerShell-7.4.6-win-x64.msi"
        try {
            Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
            Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart" -Wait
            Write-Output "[DSC Bootstrap] PowerShell 7 installed."
        } catch {
            Write-Output "[DSC Bootstrap] WARNING: Failed to install PowerShell 7: $_"
        }
    } else {
        Write-Output "[DSC Bootstrap] PowerShell 7 already present."
    }

    # ── 2. Install DSC v3 (if not already present) ──────────────────────────
    $dsc = Get-Command "dsc.exe" -ErrorAction SilentlyContinue
    if (-not $dsc) {
        Write-Output "[DSC Bootstrap] Installing DSC v3..."
        try {
            winget install --id Microsoft.DSC --accept-source-agreements --accept-package-agreements --silent
            Write-Output "[DSC Bootstrap] DSC v3 installed."
        } catch {
            Write-Output "[DSC Bootstrap] WARNING: Failed to install DSC v3: $_"
        }
    } else {
        Write-Output "[DSC Bootstrap] DSC v3 already present."
    }

    # ── 3. Apply DSC configuration ──────────────────────────────────────────
    $dscYaml = "$env:SystemRoot\Setup\Scripts\dsc-configuration.yaml"
    if (Test-Path $dscYaml) {
        Write-Output "[DSC Bootstrap] Applying DSC config from $dscYaml..."
        $dscCmd = Get-Command "dsc.exe" -ErrorAction SilentlyContinue
        if ($dscCmd) {
            & $dscCmd.Source config set --file $dscYaml 2>&1 | ForEach-Object { Write-Output "[DSC] $_" }
            Write-Output "[DSC Bootstrap] DSC apply completed (exit code: $LASTEXITCODE)."
        } else {
            Write-Output "[DSC Bootstrap] WARNING: dsc.exe not found, skipping apply."
        }
    } else {
        Write-Output "[DSC Bootstrap] No dsc-configuration.yaml found at $dscYaml — skipping apply."
    }

    Stop-Transcript
  '';

in
runCommand "autounattend-xml" { inherit dscConfigPath; } ''
    mkdir -p $out

    # If we have a DSC bootstrap script, copy it alongside the XML
    ${lib.optionalString (dscConfigPath != null) ''
    cp "${dscBootstrapScript}" "$out/apply-dsc.ps1"
    ''}

    cat > "$out/autounattend.xml" << XMLEOF
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
                              <Value>${windowsEdition}</Value>
                          </MetaData>
                      </InstallFrom>
                      <InstallTo>
                          <DiskID>0</DiskID>
                          <PartitionID>${toString windowsPartitionIndex}</PartitionID>
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
                  ${lib.optionalString disableRecoveryPartition ''
                  <RunSynchronousCommand wcm:action="add">
                      <Order>2</Order>
                      <Path>reg.exe add "HKLM\\SYSTEM\\Setup" /v DisableRecoveryPartition /t REG_DWORD /d 1 /f</Path>
                  </RunSynchronousCommand>
                  ''}
              </RunSynchronous>
          </component>
          <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <TimeZone>${timeZone}</TimeZone>
              <ComputerName>${computerName}</ComputerName>
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
                          <Name>${localUsername}</Name>
                          <Group>Administrators</Group>
                          <Password>
                              <Value>${localPassword}</Value>
                              <PlainText>true</PlainText>
                          </Password>
                      </LocalAccount>
                  </LocalAccounts>
              </UserAccounts>
              <AutoLogon>
                  <Enabled>true</Enabled>
                  <LogonCount>1</LogonCount>
                  <Username>${localUsername}</Username>
                  <Password>
                      <Value>${localPassword}</Value>
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
                  <SynchronousCommand wcm:action="add">
                      <CommandLine>powershell.exe -NoProfile -Command "Get-AppxPackage *bing* | Remove-AppxPackage"</CommandLine>
                      <Description>Remove Bing bloat</Description>
                      <Order>4</Order>
                  </SynchronousCommand>
                  ${lib.optionalString (dscConfigPath != null) ''
                  <SynchronousCommand wcm:action="add">
                      <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\apply-dsc.ps1"</CommandLine>
                      <Description>Apply DSC configuration</Description>
                      <Order>5</Order>
                  </SynchronousCommand>
                  ''}
              </FirstLogonCommands>
          </component>
      </settings>
  </unattend>
  XMLEOF

    echo "Generated autounattend.xml"
''
