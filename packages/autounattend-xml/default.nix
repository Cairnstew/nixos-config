# packages/autounattend-xml/default.nix
# Generates autounattend.xml for installing Windows to an existing partition
# TODO: Future enhancement: integrate cschneegans/unattend-generator .NET library
{ lib
, runCommand
, # Configuration arguments (override via callPackage)
  windowsPartitionIndex ? 2
, localUsername ? "user"
, localPassword ? "password123"
, timeZone ? "GMT Standard Time"
, windowsEdition ? "Windows 11 Pro"
,
}:

runCommand "autounattend.xml" { } ''
    mkdir -p $out

    # Generate autounattend.xml for installing to an existing partition
    # This is a raw XML template - future enhancement would use cschneegans/unattend-generator
    cat > $out/autounattend.xml << XMLEOF
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
              </RunSynchronous>
          </component>
          <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
              <TimeZone>${timeZone}</TimeZone>
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
              </FirstLogonCommands>
          </component>
      </settings>
  </unattend>
  XMLEOF

    echo "Generated autounattend.xml"
''
