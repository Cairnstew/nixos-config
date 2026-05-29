{ config, lib, inputs, ... }:
let
  inherit (lib) mkOption types;

  # ── Shared submodule types ─────────────────────────────────────────

  isoSubmodule = types.submodule {
    options = {
      source = mkOption {
        type = types.package;
        description = "ISO derivation or store path.";
      };
      target = mkOption {
        type = types.str;
        description = "Target path on the Ventoy USB (e.g., /iso/windows/win11.iso).";
        example = "/iso/windows/22631.7079.23H2.PRO.X64.EN.iso";
      };
    };
  };

  themeFileType = types.either types.str (types.listOf types.str);

  themeSubmodule = {
    options = {
      file = mkOption {
        type = themeFileType;
        description = "Theme.txt file path, or array of theme paths for multi-theme support.";
        example = "/ventoy/theme/blur/theme.txt";
      };
      default_file = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          0 = random on each boot, 1+ = fixed index (1-based). Only meaningful when file is an array.
        '';
      };
      resolution_fit = mkOption {
        type = types.nullOr (types.enum [ 0 1 ]);
        default = null;
        description = "Auto-select theme matching screen resolution. Requires file array + default_file=0.";
      };
      gfxmode = mkOption {
        type = types.str;
        default = "1024x768";
        description = "GRUB gfxmode (e.g. 1920x1080 or 'max' for auto).";
      };
      display_mode = mkOption {
        type = types.str;
        default = "GUI";
        description = "GUI, CLI, serial, or serial_console.";
      };
      serial_param = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Serial parameter (e.g. --unit=0 --speed=9600).";
      };
      ventoy_left = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Left position of version info (e.g. 5%).";
      };
      ventoy_top = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Top position of version info (e.g. 95%).";
      };
      ventoy_color = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Color of version info (e.g. #0000ff).";
      };
      fonts = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Font .pf2 file paths to load.";
      };
    };
  };

  menuClassSubmodule = types.submodule {
    options = {
      parent = mkOption { type = types.str; };
      class = mkOption { type = types.str; };
    };
  };

  persistenceSubmodule = types.submodule {
    options = {
      image = mkOption { type = types.str; };
      backend = mkOption { type = types.str; };
    };
  };

  injectionSubmodule = types.submodule {
    options = {
      image = mkOption { type = types.str; };
      dir = mkOption { type = types.str; };
    };
  };

  autoInstallSubmodule = types.submodule {
    options = {
      image = mkOption {
        type = types.str;
        description = "Full path of the ISO image file (supports fuzzy matching).";
      };
      parent = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Full path of the parent directory — all ISOs under it use this template.";
      };
      template = mkOption {
        type = types.either types.str (types.listOf types.str);
        description = ''
          Template path(s) on the Ventoy USB. Use an array for multiple profiles;
          Ventoy shows a boot-time menu to pick which one to apply.
        '';
        example = [ "/ventoy/scripts/dev.xml" "/ventoy/scripts/prod.xml" ];
      };
      autosel = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Auto-select which template (1-based). 0 = no template, 1+ = select template N.";
      };
      timeout = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Prompt menu timeout. Unset = no menu (uses autosel). 0 = wait forever. >0 = auto-select after N seconds.";
      };
    };
  };

  confReplaceSubmodule = types.submodule {
    options = {
      image = mkOption { type = types.str; };
      file = mkOption { type = types.str; };
    };
  };

  menuAliasSubmodule = types.submodule {
    options = {
      image = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Full path of the image file (supports fuzzy matching).";
      };
      dir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Full path of the directory (no trailing slash).";
      };
      alias = mkOption {
        type = types.str;
        description = "Alias shown in the boot menu (Unicode supported).";
      };
    };
  };

  menuTipSubmodule = {
    options = {
      left = mkOption {
        type = types.str;
        default = "10%";
        description = "X position of the tip.";
      };
      top = mkOption {
        type = types.str;
        default = "81%";
        description = "Y position of the tip.";
      };
      color = mkOption {
        type = types.str;
        default = "blue";
        description = "Tip color (name or #RRGGBB).";
      };
      tips = mkOption {
        type = types.listOf (types.submodule {
          options = {
            image = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Full path of the image file (supports fuzzy matching).";
            };
            dir = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Full path of the directory (no trailing slash).";
            };
            tip = mkOption {
              type = types.str;
              description = "Tip message (single line only).";
            };
          };
        });
        default = [ ];
        description = "Tip entries for specific images or directories.";
      };
    };
  };

  dudSubmodule = types.submodule {
    options = {
      image = mkOption {
        type = types.str;
        description = "Full path of the ISO image file.";
      };
      dud = mkOption {
        type = types.either types.str (types.listOf types.str);
        description = "Full path (or array) of DUD image files.";
      };
    };
  };

  wimbootSubmodule = types.submodule {
    options = {
      image = mkOption { type = types.str; };
      wimboot = mkOption { type = types.attrs; };
    };
  };

  vhdbootSubmodule = types.submodule {
    options = {
      image = mkOption { type = types.str; };
      vhdboot = mkOption { type = types.attrs; };
    };
  };

  vtoybootSubmodule = types.submodule {
    options = {
      image = mkOption { type = types.str; };
      vtoyboot = mkOption { type = types.attrs; };
    };
  };

  # ── Helper to flatten dual-mode plugin options ────────────────────
  # Ventoy supports suffix-based per-BIOS-mode keys:
  #   control, control_uefi, control_legacy, control_ia32, control_aa64, control_mips
  # Same pattern for all plugins. We build an attrset of option declarations.
  pluginOptionTypes = {
    control           = types.listOf types.attrs;
    theme             = types.nullOr (types.submodule themeSubmodule);
    menu_class        = types.listOf menuClassSubmodule;
    persistence       = types.listOf persistenceSubmodule;
    injection         = types.listOf injectionSubmodule;
    auto_install      = types.listOf autoInstallSubmodule;
    conf_replace      = types.listOf confReplaceSubmodule;
    menu_alias        = types.listOf menuAliasSubmodule;
    menu_tip          = types.nullOr (types.submodule menuTipSubmodule);
    image_list        = types.listOf types.str;
    image_blacklist   = types.listOf types.str;
    password          = types.attrs;
    dud               = types.listOf dudSubmodule;
    wimboot           = types.listOf wimbootSubmodule;
    vhdboot           = types.listOf vhdbootSubmodule;
    vtoyboot          = types.listOf vtoybootSubmodule;
    auto_memdisk      = types.listOf types.str;
  };

  modeSuffixes = [ "" "legacy" "uefi" "ia32" "aa64" "mips" ];

  pluginDescriptions = {
    control         = "Global control settings";
    theme           = "Theme configuration";
    menu_class      = "Menu class mappings for CSS theming";
    persistence     = "Persistence backend mappings";
    injection       = "File injection rules";
    auto_install    = "Auto-install preseed/kickstart templates";
    conf_replace    = "GRUB config replacement snippets";
    menu_alias      = "Menu alias definitions (friendly names)";
    menu_tip        = "Menu tip configuration";
    image_list      = "Image whitelist — only listed files shown in menu";
    image_blacklist = "Image blacklist — hide listed files from menu";
    password        = "Password protection settings (use with caution — stored in /nix/store)";
    dud             = "Driver Update Disk mappings (RHEL/CentOS/SUSE)";
    wimboot         = "Wimboot configuration";
    vhdboot         = "Windows VHD/VHDX boot configuration";
    vtoyboot        = "Linux vDisk boot configuration";
    auto_memdisk    = "Image paths to auto-boot in Memdisk mode";
  };

  modeDescriptions = {
    ""      = "all boot modes";
    legacy  = "x86 Legacy BIOS mode";
    uefi    = "x86_64 UEFI mode";
    ia32    = "IA32 UEFI mode";
    aa64    = "ARM64 UEFI mode";
    mips    = "MIPS64 UEFI mode";
  };

  # Sensible default for each plugin (used for all suffix variants)
  pluginDefaults = {
    control         = [ ];
    theme           = null;
    menu_class      = [ ];
    persistence     = [ ];
    injection       = [ ];
    auto_install    = [ ];
    conf_replace    = [ ];
    menu_alias      = [ ];
    menu_tip        = null;
    image_list      = [ ];
    image_blacklist = [ ];
    password        = { };
    dud             = [ ];
    wimboot         = [ ];
    vhdboot         = [ ];
    vtoyboot        = [ ];
    auto_memdisk    = [ ];
  };

  # Build the flat option attrset from pluginOptionTypes + modeSuffixes
  pluginOptions = lib.listToAttrs (lib.flatten (lib.mapAttrsToList (name: optType:
    map (suffix: let
      key = if suffix == "" then name else "${name}_${suffix}";
    in {
      name = key;
      value = mkOption {
        type = optType;
        default = pluginDefaults.${name};
        description = "${pluginDescriptions.${name}}. Applied in ${modeDescriptions.${suffix}}.";
      };
    }) modeSuffixes
  ) pluginOptionTypes));

in
{
  options.ventoy = {
    isos = mkOption {
      type = types.attrsOf isoSubmodule;
      default = { };
      description = "ISO entries to deploy to the Ventoy USB.";
    };

    deployFiles = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          source = mkOption {
            type = types.package;
            description = "File derivation or store path to deploy.";
          };
          target = mkOption {
            type = types.str;
            description = "Target path on the Ventoy USB (e.g., /ventoy/scripts/autounattend.xml).";
            example = "/ventoy/scripts/autounattend.xml";
          };
        };
      });
      default = { };
      description = "Extra files to deploy to the Ventoy USB (e.g., unattended answer files, scripts).";
    };

    settings = pluginOptions;

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Extra ventoy.json keys merged at the top level. Use for ad-hoc keys,
        unsupported plugins, or to work around module limitations.
      '';
      example = {
        VTOY_WIN11_BYPASS_CHECK = "1";
        VTOY_SECONDARY_BOOT_MENU_TIMEOUT = "0";
      };
    };

    device = mkOption {
      type = types.str;
      default = "";
      example = "/dev/sdb";
      description = "Default Ventoy USB device for deploy. Leave empty for auto-detection.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/ventoy";
      description = "Mount point for the Ventoy data partition.";
    };

    grubConfig = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = ''
        Custom ventoy_grub.cfg for the Menu Extension Plugin (press F6 in Ventoy menu).
      '';
      example = ./ventoy_grub.cfg;
    };

    installOptions = {
      secureBoot = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Secure Boot support when installing Ventoy (-s flag).";
      };
      gpt = mkOption {
        type = types.bool;
        default = false;
        description = "Use GPT partition style instead of MBR when installing (-g flag).";
      };
      label = mkOption {
        type = types.str;
        default = "Ventoy";
        description = "Label for the main data partition (-L flag).";
      };
      reserveSizeMb = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Preserve space at bottom of disk (-r SIZE_MB). Only for install.";
      };
    };

    answerFileSettings.username = mkOption {
      type = types.str;
      default = "user";
      description = "Default local account username for generated answer files.";
    };
    answerFileSettings.hostname = mkOption {
      type = types.str;
      default = "HOST-####";
      description = "Default computer name pattern for generated answer files.";
    };
    answerFileSettings.password = mkOption {
      type = types.str;
      default = "password";
      description = "Default local account password for generated answer files.";
    };
    answerFileSettings.extraFlags = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra GenerateAnswerFile flags appended to all answer file profiles.";
    };
    answerFileSettings.diskId = mkOption {
      type = types.str;
      default = "0";
      description = "Target disk ID for Windows installation. Run `lsblk` from a live NixOS USB to find yours. When booting from Ventoy, the internal drive is usually 1.";
      example = "1";
    };
  };

  config.perSystem = { pkgs, ... }:
    let
      vCfg = config.ventoy;

      # ── Answer file profiles ─────────────────────────────────────
      # Generates Windows unattended answer XML directly (no GenerateAnswerFile).
      # Each profile becomes packages.windows-answ-pro-<name>.
      # Reference them in ventoy.deployFiles + ventoy.settings.auto_install.
      answerSettings = vCfg.answerFileSettings;
      diskCfg = vCfg.answerFileSettings;
      buildAnswer = { name, productKey, computerName, username, password
                    , autoLogonCount ? "1"
                    , lang ? "en-GB"
                    , timezone ? "GMT Standard Time"
                    , arch ? "amd64"
                    , networkLocale ? "Work"
                    , protectYourPC ? "3"
                    , wipeDisk ? false
                    }: let
        archId = if arch == "amd64" then "x86_64" else arch;
      in pkgs.runCommand "${name}.xml" {} ''
        cat > "$out" << 'XML_EOF'
        <?xml version="1.0" encoding="utf-8"?>
        <unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
          <settings pass="windowsPE">
            <component name="Microsoft-Windows-Setup" processorArchitecture="${arch}" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
              <UserData>
                <ProductKey>
                  <Key>${productKey}</Key>
                  <WillShowUI>OnError</WillShowUI>
                </ProductKey>
                <AcceptEula>true</AcceptEula>
              </UserData>
              ${lib.optionalString wipeDisk ''
              <DiskConfiguration>
                <Disk wcm:action="add">
                  <DiskID>${diskCfg.diskId}</DiskID>
                  <WillWipeDisk>true</WillWipeDisk>
                  <CreatePartitions>
                    <CreatePartition wcm:action="add">
                      <Order>1</Order>
                      <Type>EFI</Type>
                      <Size>512</Size>
                    </CreatePartition>
                    <CreatePartition wcm:action="add">
                      <Order>2</Order>
                      <Type>MSR</Type>
                      <Size>16</Size>
                    </CreatePartition>
                    <CreatePartition wcm:action="add">
                      <Order>3</Order>
                      <Type>Primary</Type>
                      <Size>81920</Size>
                    </CreatePartition>
                  </CreatePartitions>
                  <ModifyPartitions>
                    <ModifyPartition wcm:action="add">
                      <Order>1</Order>
                      <PartitionID>1</PartitionID>
                      <Format>FAT32</Format>
                      <Label>EFI</Label>
                    </ModifyPartition>
                    <ModifyPartition wcm:action="add">
                      <Order>2</Order>
                      <PartitionID>2</PartitionID>
                    </ModifyPartition>
                    <ModifyPartition wcm:action="add">
                      <Order>3</Order>
                      <PartitionID>3</PartitionID>
                      <Format>NTFS</Format>
                      <Label>Windows</Label>
                      <Letter>C</Letter>
                    </ModifyPartition>
                  </ModifyPartitions>
                </Disk>
              </DiskConfiguration>
              <ImageInstall>
                <OSImage>
                  <InstallTo>
                    <DiskID>${diskCfg.diskId}</DiskID>
                    <PartitionID>3</PartitionID>
                  </InstallTo>
                  <WillShowUI>OnError</WillShowUI>
                </OSImage>
              </ImageInstall>
              ''}
              <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                  <Order>1</Order>
                  <Description>Bypass TPM check</Description>
                  <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>2</Order>
                  <Description>Bypass SecureBoot check</Description>
                  <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>3</Order>
                  <Description>Bypass storage check</Description>
                  <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>4</Order>
                  <Description>Bypass CPU check</Description>
                  <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>5</Order>
                  <Description>Bypass RAM check</Description>
                  <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>6</Order>
                  <Description>Bypass disk check</Description>
                  <Path>reg.exe add "HKLM\SYSTEM\Setup\LabConfig" /v BypassDiskCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
              </RunSynchronous>
            </component>
          </settings>
          <settings pass="specialize">
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="${arch}" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
              <ComputerName>${computerName}</ComputerName>
              <ProductKey>${productKey}</ProductKey>
            </component>
            <component name="Microsoft-Windows-Deployment" processorArchitecture="${arch}" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
              <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                  <Order>1</Order>
                  <Description>Bypass NRO (local account creation)</Description>
                  <Path>reg.exe add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                  <Order>2</Order>
                  <Description>Disable network adapters for local account OOBE</Description>
                  <Path>powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Get-NetAdapter | Disable-NetAdapter -Confirm:`$false"</Path>
                </RunSynchronousCommand>
              </RunSynchronous>
            </component>
            <component name="Microsoft-Windows-International-Core" processorArchitecture="${arch}" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
              <InputLocale>${lang}</InputLocale>
              <SystemLocale>${lang}</SystemLocale>
              <UILanguage>${lang}</UILanguage>
              <UserLocale>${lang}</UserLocale>
            </component>
          </settings>
          <settings pass="oobeSystem">
            <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="${arch}" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
              <UserAccounts>
                <LocalAccounts>
                  <LocalAccount wcm:action="add">
                    <Password>
                      <Value>${password}</Value>
                      <PlainText>true</PlainText>
                    </Password>
                    <Description>${username}</Description>
                    <DisplayName>${username}</DisplayName>
                    <Group>Administrators</Group>
                    <Name>${username}</Name>
                  </LocalAccount>
                </LocalAccounts>
              </UserAccounts>
              <AutoLogon>
                <Enabled>true</Enabled>
                <LogonCount>${autoLogonCount}</LogonCount>
                <Username>${username}</Username>
                <Password>
                  <Value>${password}</Value>
                  <PlainText>true</PlainText>
                </Password>
              </AutoLogon>
              <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>${networkLocale}</NetworkLocation>
                <ProtectYourPC>${protectYourPC}</ProtectYourPC>
              </OOBE>
              <TimeZone>${timezone}</TimeZone>
              <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                  <Order>1</Order>
                  <Description>Re-enable network adapters</Description>
                  <CommandLine>powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Get-NetAdapter | Enable-NetAdapter -Confirm:`$false"</CommandLine>
                </SynchronousCommand>
              </FirstLogonCommands>
            </component>
            <component name="Microsoft-Windows-International-Core" processorArchitecture="${arch}" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
              <InputLocale>${lang}</InputLocale>
              <SystemLocale>${lang}</SystemLocale>
              <UILanguage>${lang}</UILanguage>
              <UserLocale>${lang}</UserLocale>
            </component>
          </settings>
        </unattend>
        XML_EOF
      '';

      answerFileConfigs = {
        dev = {
          name = "dev";
          extraFlags = answerSettings.extraFlags;
          computerName = "DEV-PC-####";
          username = "seanc";
          password = "password";
          autoLogonCount = "3";
        };
        minimal = {
          name = "minimal";
          extraFlags = answerSettings.extraFlags;
          computerName = "MIN-####";
          username = "user";
          password = "password";
        };
        domain = {
          name = "domain";
          extraFlags = answerSettings.extraFlags;
          computerName = "CORP-####";
          username = "user";
          password = "password";
        };
        kiosk = {
          name = "kiosk";
          extraFlags = answerSettings.extraFlags;
          computerName = "KIOSK-####";
          username = "kiosk";
          password = "kiosk";
          autoLogonCount = "999";
        };
        dual-boot = {
          name = "dual-boot";
          extraFlags = answerSettings.extraFlags;
          computerName = answerSettings.hostname;
          username = answerSettings.username;
          password = answerSettings.password;
          autoLogonCount = "1";
          wipeDisk = true;
        };
      };
      answerFilePackages = lib.mapAttrs' (n: v:
        lib.nameValuePair "windows-answ-pro-${n}" (buildAnswer {
          inherit (v) name computerName username password;
          productKey = "VK7JG-NPHTM-C97JM-9MPGT-3V66T";
          autoLogonCount = v.autoLogonCount or "1";
          wipeDisk = v.wipeDisk or false;
          lang = "en-GB";
          timezone = "GMT Standard Time";
          arch = "amd64";
        })
      ) answerFileConfigs;

      # ── Build ventoy.json ────────────────────────────────────────
      # Collect every non-empty/non-null plugin key from settings
      knownPluginKeys = builtins.attrNames pluginOptionTypes;

      # Serialise a theme value (strip null/default fields)
      mkThemeJson = theme: lib.filterAttrs (_: v: v != null && v != [ ]) {
        inherit (theme) file gfxmode display_mode fonts;
      } // lib.optionalAttrs (theme.default_file != null) {
        default_file = theme.default_file;
      } // lib.optionalAttrs (theme.resolution_fit != null) {
        resolution_fit = theme.resolution_fit;
      } // lib.optionalAttrs (theme.serial_param != null) {
        serial_param = theme.serial_param;
      } // lib.optionalAttrs (theme.ventoy_left != null) {
        ventoy_left = theme.ventoy_left;
      } // lib.optionalAttrs (theme.ventoy_top != null) {
        ventoy_top = theme.ventoy_top;
      } // lib.optionalAttrs (theme.ventoy_color != null) {
        ventoy_color = theme.ventoy_color;
      };

      # ── JSON cleanup ──────────────────────────────────────────────
      # Recursively strip null/empty values from attrs and lists so the
      # generated JSON matches Ventoy's expectations (no null keys).
      cleanJSON = val:
        if builtins.isAttrs val then
          lib.filterAttrs (_: v: v != null)
            (lib.mapAttrs (_: v: cleanJSON v) val)
        else if builtins.isList val then
          builtins.filter (v: v != null)
            (map (v: cleanJSON v) val)
        else
          val;

      # Check if a value should be included in ventoy.json (top-level plugin key)
      shouldInclude = val:
        val != null
        && !(builtins.isList val && val == [ ])
        && !(val == { });

      # Clean nested nulls from submodule entries (menu_alias, auto_install, etc.)
      cleanPluginValue = baseName: raw:
        if raw == null then null
        else if baseName == "theme" then mkThemeJson raw
        else if builtins.isList raw then map cleanJSON raw
        else if builtins.isAttrs raw then cleanJSON raw
        else raw;

      ventoyJson = let
        entries = lib.flatten (lib.forEach knownPluginKeys (baseName:
          lib.forEach modeSuffixes (suffix: let
            key = if suffix == "" then baseName else "${baseName}_${suffix}";
            raw = vCfg.settings.${key} or null;
            cleaned = cleanPluginValue baseName raw;
          in lib.optional (shouldInclude cleaned) {
            name = key;
            value = cleaned;
          })
        ));
      in builtins.listToAttrs entries // vCfg.extraConfig;

      ventoyJsonFile = pkgs.writeText "ventoy.json" (builtins.toJSON ventoyJson);

      # Extract content hash from a store path (the base32 hash in the path name)
      storeHash = p:
        let name = builtins.baseNameOf p;
        in lib.head (lib.splitString "-" name);

      # GParted ISO: flake=false input is an attrset that fails types.package;
      # wrap in runCommand to produce a real derivation.
      gpartedIso = pkgs.runCommand "gparted-live-1.6.0-1-amd64.iso" { } ''
        cp ${inputs.gparted-iso} $out
      '';

      allIsos = vCfg.isos // {
        gparted = {
          source = gpartedIso;
          target = "/iso/linux/gparted-live-1.6.0-1-amd64.iso";
        };
      };

      isoMappings = lib.mapAttrsToList (name: iso:
        ''"${iso.source}|${iso.target}|${storeHash iso.source}"''
      ) allIsos;

      fileMappings = lib.mapAttrsToList (name: pkg:
        let
          profileName = lib.removePrefix "windows-answ-pro-" name;
          target = "/ventoy/scripts/${profileName}.xml";
        in
        ''"${pkg}|${target}|${storeHash pkg}"''
      ) answerFilePackages;

      grubConfigRef = vCfg.grubConfig;

      # ── Install/update shell functions ────────────────────────────
      installScript = let
        opts = vCfg.installOptions;
      in ''
        do_install() {
          local dev="$1" mode="$2"
          local flags=()

          ${lib.optionalString opts.secureBoot ''flags+=(-s)''}
          ${lib.optionalString opts.gpt ''flags+=(-g)''}
          ${lib.optionalString (opts.label != "Ventoy") ''flags+=(-L "${opts.label}")''}
          ${lib.optionalString (opts.reserveSizeMb != null) ''flags+=(-r ${toString opts.reserveSizeMb})''}

          local cmd
          case "$mode" in
            install)       cmd="-i" ;;
            force-install) cmd="-I" ;;
            update)        cmd="-u" ;;
          esac

          echo "Running Ventoy2Disk.sh $cmd ($mode) on $dev"
          if ! command -v Ventoy2Disk.sh &>/dev/null; then
            echo "  [FAIL] Ventoy2Disk.sh not found in PATH. Install ventoy or ventoy-full package." >&2
            return 1
          fi
          sudo Ventoy2Disk.sh "$cmd" ''${flags[@]+"''${flags[@]}"} "$dev"
        }

        do_info() {
          local dev="$1"
          if command -v Ventoy2Disk.sh &>/dev/null; then
            sudo Ventoy2Disk.sh -l "$dev"
          elif command -v ventoy &>/dev/null; then
            ventoy -l "$dev"
          else
            echo "  [INFO] No ventoy CLI found."
          fi
        }

        # ── Interactive wizard ─────────────────────────────────────────

        wizard_install() {
          local dev="$1"
          local info model size

          model=$(lsblk -dno MODEL "$dev" 2>/dev/null || echo "unknown")
          size=$(lsblk -dno SIZE "$dev" 2>/dev/null || echo "unknown")
          mounts=$(findmnt -n -o TARGET --source "$dev" 2>/dev/null | paste -sd, || echo "none")

          echo ""
          echo "============================================"
          echo "  USB Drive Selected"
          echo "============================================"
          echo "  Device:     $dev"
          echo "  Model:      $model"
          echo "  Size:       $size"
          echo "  Mounted at: $mounts"
          echo ""
          echo "  Ventoy is NOT installed on this device."
          echo "  Installing Ventoy will FORMAT the entire drive."
          echo "  ALL EXISTING DATA WILL BE LOST."
          echo "============================================"
          echo ""

          if [[ $ASSUME_YES -eq 0 ]]; then
            local reply
            read -p "Install Ventoy to $dev and deploy? [y/N] " reply
            case "$reply" in
              y|Y|yes|Yes|YES) ;;
              *)
                echo "Aborted."
                exit 1
                ;;
            esac
          fi

          echo ""
          echo "Installing Ventoy to $dev ..."
          do_install "$dev" "install"
          echo "Ventoy installation complete."
          echo ""
        }
      '';
    in
    let
      basePackages = {
        ventoy-deploy = pkgs.writeShellScriptBin "ventoy-deploy" ''
        set -euo pipefail

        VENTOY_JSON="${ventoyJsonFile}"
        ${lib.optionalString (grubConfigRef != null) ''GRUB_CFG="${grubConfigRef}"''}
        ISO_MAPPINGS=(
          ${lib.concatStringsSep "\n          " isoMappings}
        )
        FILE_MAPPINGS=(
          ${lib.concatStringsSep "\n          " fileMappings}
        )
        DEFAULT_DEVICE="${vCfg.device}"
        MOUNT_POINT="${vCfg.mountPoint}"

        CHECK_ONLY=0
        ASSUME_YES=0
        DEVICE="$DEFAULT_DEVICE"
        MOUNT=""
        CLEANUP=0
        MODE="deploy"

        ${installScript}

        usage() {
          cat <<'USAGE'
        Usage: ventoy-deploy [OPTIONS] [DEVICE|MOUNT_PATH]

        Deploy ISOs and ventoy.json to a Ventoy USB, or check/install/manage.

        Deploy commands:
          (no args)             Auto-detect USB, mount, deploy ISOs + config
          -c, --check           Verify Ventoy installation only (no deploy)
          -m, --mount PATH      Already-mounted Ventoy data partition
          -d, --device DEVICE   USB block device (e.g., /dev/sdb)

        Install/Update commands:
          --install DEVICE       Install Ventoy to DEVICE (runs Ventoy2Disk.sh -i)
          --force-install DEVICE Force install Ventoy (-I)
          --update DEVICE        Update Ventoy on DEVICE (-u)
          --info DEVICE          Show Ventoy info on DEVICE (-l)

        Wizards:
          --wizard              Force interactive USB selection + install wizard
          -y, --yes             Auto-confirm prompts (for scripting)

        Global options:
          -h, --help            Show this help
        USAGE
          exit 0
        }

        # ── Device detection ──────────────────────────────────────────

        # Print device info for display
        dev_info() {
          local dev="$1" model size
          model=$(lsblk -dno MODEL "$dev" 2>/dev/null || echo "unknown")
          size=$(lsblk -dno SIZE "$dev" 2>/dev/null || echo "unknown")
          echo "$dev ($model, $size)"
        }

        # Check if a device has Ventoy installed (by label + ventoy -l)
        is_ventoy() {
          local dev="$1"
          local labels
          labels=$(lsblk -nlo LABEL "$dev" 2>/dev/null)
          echo "$labels" | grep -qiE "VTOYEFI|VENTOY" || return 1
          if command -v ventoy &>/dev/null; then
            ventoy -l "$dev" &>/dev/null 2>&1 || return 1
          fi
          return 0
        }

        # Find existing Ventoy USB → prints device path, returns 0
        auto_detect_ventoy() {
          local dev
          for dev in $(lsblk -dno NAME,RM 2>/dev/null | awk '$2 == "1" {print $1}'); do
            dev="/dev/$dev"
            if is_ventoy "$dev"; then
              echo "$dev"
              return 0
            fi
          done
          for dev in $(lsblk -dno NAME,RM 2>/dev/null | awk '$2 != "1" {print $1}'); do
            dev="/dev/$dev"
            if is_ventoy "$dev"; then
              echo "$dev"
              return 0
            fi
          done
          return 1
        }

        # List all removable USB drives (non-Ventoy) → prints one per line
        list_removable_usbs() {
          local dev
          for dev in $(lsblk -dno NAME,RM 2>/dev/null | awk '$2 == "1" {print $1}'); do
            dev="/dev/$dev"
            if ! is_ventoy "$dev" 2>/dev/null; then
              dev_info "$dev"
            fi
          done
        }

        # Pick a removable USB interactively, or return the only one
        pick_usb() {
          local usbs=()
          local dev line i choice

          while IFS= read -r line; do
            usbs+=("$line")
          done < <(list_removable_usbs)

          if [[ "''${#usbs[@]}" -eq 0 ]]; then
            return 1
          fi

          if [[ "''${#usbs[@]}" -eq 1 ]]; then
            echo "''${usbs[0]}" | awk '{print $1}'
            return 0
          fi

          echo ""
          echo "Multiple USB drives found. Choose one:"
          for i in "''${!usbs[@]}"; do
            echo "  [$((i+1))] ''${usbs[$i]}"
          done
          echo ""
          read -p "Select USB [1-''${#usbs[@]}]: " choice
          choice=$((choice - 1))
          if [[ $choice -ge 0 ]] && [[ $choice -lt "''${#usbs[@]}" ]]; then
            echo "''${usbs[$choice]}" | awk '{print $1}'
            return 0
          fi
          return 1
        }

        find_data_partition() {
          local dev="$1" parts part label upper

          parts=$(lsblk -nlo NAME,LABEL "$dev" 2>/dev/null)
          while IFS=' ' read -r part label _; do
            upper=$(echo "$label" | tr '[:lower:]' '[:upper:]')
            if [[ "$upper" == "VENTOY" ]] && [[ -n "$part" ]]; then
              echo "/dev/$part"
              return 0
            fi
          done <<< "$parts"

          while IFS=' ' read -r part label _; do
            upper=$(echo "$label" | tr '[:lower:]' '[:upper:]')
            if [[ "$upper" != "VTOYEFI" ]] && [[ -n "$part" ]]; then
              echo "/dev/$part"
              return 0
            fi
          done <<< "$parts"

          echo "''${dev}2"
        }

        find_existing_mount() {
          local data_part="$1"
          findmnt -n -o TARGET --source "$data_part" 2>/dev/null || true
        }

        # ── Verification ─────────────────────────────────────────────

        verify_ventoy() {
          local dev="$1" mount="$2"
          local errors=0 total_bytes=0 size avail_1k avail_bytes

          echo ""
          echo "=== Ventoy Installation Check ==="

          if [[ -n "$dev" ]]; then
            if command -v ventoy &>/dev/null; then
              if ventoy -l "$dev" &>/dev/null 2>&1; then
                echo "  [OK] ventoy -l: Device recognized as Ventoy"
              else
                echo "  [FAIL] ventoy -l: Device not recognized as Ventoy" >&2
                errors=1
              fi
            fi

            if lsblk -nlo LABEL "$dev" 2>/dev/null | grep -qi "VTOYEFI"; then
              echo "  [OK] VTOYEFI partition found"
            else
              echo "  [WARN] No VTOYEFI partition found (may be MBR layout)" >&2
            fi
          fi

          if [[ -n "$mount" ]]; then
            if [[ -d "$mount/ventoy" ]]; then
              echo "  [OK] ventoy/ directory exists"
            else
              echo "  [INFO] ventoy/ directory will be created on deploy"
            fi

            if [[ "''${#ISO_MAPPINGS[@]}" -gt 0 ]]; then
              for mapping in "''${ISO_MAPPINGS[@]}"; do
                local src="''${mapping%|*}"
                if [[ -f "$src" ]]; then
                  size=$(stat -c%s "$src" 2>/dev/null || echo 0)
                  total_bytes=$((total_bytes + size))
                fi
              done

              if [[ $total_bytes -gt 0 ]]; then
                avail_1k=$(df --output=avail "$mount" 2>/dev/null | tail -1)
                if [[ -n "$avail_1k" ]]; then
                  avail_bytes=$((avail_1k * 1024))
                  if [[ $total_bytes -le $avail_bytes ]]; then
                    echo "  [OK] Disk space: $((total_bytes / 1024 / 1024))M needed, $((avail_bytes / 1024 / 1024))M available"
                  else
                    echo "  [FAIL] Insufficient space: $((total_bytes / 1024 / 1024))M needed, $((avail_bytes / 1024 / 1024))M available" >&2
                    errors=1
                  fi
                fi
              fi
            fi
          fi

          if [[ $errors -eq 0 ]]; then
            echo "  [OK] Ventoy USB is ready"
          fi
          return $errors
        }

          # ── Deploy ───────────────────────────────────────────────────

        deploy_isos() {
          local mount="$1" errors=0 src_size dest_size
          local ventoy_dir="$mount/ventoy"
          local state_file="$ventoy_dir/.deploy-state"
          local changed=0

          # Load previous state (source hashes from last deploy)
          declare -A prev_hashes
          if [[ -f "$state_file" ]]; then
            while IFS='|' read -r prev_target prev_hash; do
              prev_hashes["$prev_target"]="$prev_hash"
            done < "$state_file"
          fi

          # ventoy.json goes to <partition_root>/ventoy/ventoy.json
          mkdir -p "$ventoy_dir"
          cp "$VENTOY_JSON" "$ventoy_dir/ventoy.json"
          src_size=$(stat -c%s "$VENTOY_JSON" 2>/dev/null || echo 0)
          dest_size=$(stat -c%s "$ventoy_dir/ventoy.json" 2>/dev/null || echo 0)
          if [[ "$src_size" -eq 0 ]] || [[ "$src_size" -ne "$dest_size" ]]; then
            echo "  [FAIL] Failed to deploy ventoy.json" >&2
            errors=1
          else
            echo "  [OK] Deployed ventoy/ventoy.json"
          fi

          # ventoy_grub.cfg (Menu Extension Plugin — F6)
          if [[ -n "''${GRUB_CFG:-}" ]] && [[ -f "$GRUB_CFG" ]]; then
            cp "$GRUB_CFG" "$ventoy_dir/ventoy_grub.cfg"
            src_size=$(stat -c%s "$GRUB_CFG" 2>/dev/null || echo 0)
            dest_size=$(stat -c%s "$ventoy_dir/ventoy_grub.cfg" 2>/dev/null || echo 0)
            if [[ "$src_size" -eq 0 ]] || [[ "$src_size" -ne "$dest_size" ]]; then
              echo "  [FAIL] Failed to deploy ventoy_grub.cfg" >&2
              errors=1
            else
              echo "  [OK] Deployed ventoy/ventoy_grub.cfg"
            fi
          fi

          # Temp file for new state (on same filesystem as state_file)
          local new_state
          new_state=$(mktemp -p "$(dirname "$state_file")" .deploy-state.XXXXXX)

          # Deploy ISOs to configured target paths
          for mapping in "''${ISO_MAPPINGS[@]}"; do
            IFS='|' read -r source target hash <<< "$mapping"
            local dest="$mount/$target"
            mkdir -p "$(dirname "$dest")"

            # Check if hash changed since last deploy (source was rebuilt)
            local prev_hash="''${prev_hashes[$target]:-}"
            if [[ -n "$prev_hash" ]] && [[ "$prev_hash" != "$hash" ]]; then
              echo "  [CHANGED] $(basename "$source") (new hash: $hash)"
              changed=1
            fi

            src_size=$(stat -c%s "$source" 2>/dev/null || echo 0)
            dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)

            if [[ -f "$dest" ]] && [[ "$src_size" -eq "$dest_size" ]] && [[ "$changed" -eq 0 ]]; then
              echo "  [SKIP] $(basename "$source") -> $target (up to date, $((src_size / 1024 / 1024))M)"
              echo "''${target}|''${hash}" >> "$new_state"
              continue
            fi

            echo "  Copying $(basename "$source") -> $target ($((src_size / 1024 / 1024))M)"
            cp -L "$source" "$dest"

            dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
            if [[ "$src_size" -ne "$dest_size" ]]; then
              echo "  [FAIL] Size mismatch for $target ($src_size vs $dest_size)" >&2
              errors=1
            else
              echo "  [OK] Verified $target ($((src_size / 1024 / 1024))M)"
              echo "''${target}|''${hash}" >> "$new_state"
            fi
            changed=0
          done

          # Deploy extra files (answer files, scripts, etc.)
          for mapping in "''${FILE_MAPPINGS[@]}"; do
            IFS='|' read -r source target hash <<< "$mapping"
            local dest="$mount/$target"
            mkdir -p "$(dirname "$dest")"

            # Check if hash changed
            local prev_hash="''${prev_hashes[$target]:-}"
            if [[ -n "$prev_hash" ]] && [[ "$prev_hash" != "$hash" ]]; then
              echo "  [CHANGED] $(basename "$source") (new hash: $hash)"
              changed=1
            fi

            src_size=$(stat -c%s "$source" 2>/dev/null || echo 0)
            dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)

            if [[ -f "$dest" ]] && [[ "$src_size" -eq "$dest_size" ]] && [[ "$changed" -eq 0 ]]; then
              echo "  [SKIP] $(basename "$source") -> $target ($((src_size / 1024))B, up to date)"
              echo "''${target}|''${hash}" >> "$new_state"
              continue
            fi

            echo "  Copying $(basename "$source") -> $target ($((src_size / 1024))KB)"
            cp -L "$source" "$dest"

            dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
            if [[ "$src_size" -ne "$dest_size" ]]; then
              echo "  [FAIL] Size mismatch for $target" >&2
              errors=1
            else
              echo "  [OK] Verified $target ($((src_size / 1024))KB)"
              echo "''${target}|''${hash}" >> "$new_state"
            fi
            changed=0
          done

          # Write new state (same filesystem, mv is atomic)
          mv "$new_state" "$state_file"

          return $errors
        }

        # ── Main ─────────────────────────────────────────────────────

        main() {
          local WIZARD_MODE=0

          while [[ $# -gt 0 ]]; do
            case "$1" in
              -c|--check)      CHECK_ONLY=1; shift ;;
              -d|--device)     DEVICE="$2"; shift 2 ;;
              -m|--mount)      MOUNT="$2";  shift 2 ;;
              --install)       MODE="install"; DEVICE="$2"; shift 2 ;;
              --force-install) MODE="force-install"; DEVICE="$2"; shift 2 ;;
              --update)        MODE="update"; DEVICE="$2"; shift 2 ;;
              --info)          MODE="info"; DEVICE="$2"; shift 2 ;;
              --wizard)        WIZARD_MODE=1; shift ;;
              -y|--yes)        ASSUME_YES=1; shift ;;
              -h|--help)       usage ;;
              *)
                if [[ "$1" == /dev/* ]] || [[ "$1" =~ ^sd[a-z]$ ]]; then
                  DEVICE="$1"
                else
                  MOUNT="$1"
                fi
                shift
                ;;
            esac
          done

          # ── Install/Update/Info mode ─────────────────────────────
          if [[ "$MODE" == "install" || "$MODE" == "force-install" || "$MODE" == "update" ]]; then
            if [[ -z "$DEVICE" ]]; then
              echo "Error: --$MODE requires a device (e.g., /dev/sdb)." >&2
              exit 1
            fi
            do_install "$DEVICE" "$MODE"
            exit $?
          fi

          if [[ "$MODE" == "info" ]]; then
            if [[ -z "$DEVICE" ]]; then
              echo "Error: --info requires a device." >&2
              exit 1
            fi
            do_info "$DEVICE"
            exit $?
          fi

          # ── Deploy mode ──────────────────────────────────────────
          # Step 1: Auto-detect
          if [[ -z "$DEVICE" ]] && [[ -z "$MOUNT" ]]; then
            local detected

            if [[ $WIZARD_MODE -eq 1 ]]; then
              # Wizard: let user pick any USB, install Ventoy if needed
              detected=$(pick_usb) || {
                echo "Error: No removable USB drives found." >&2
                exit 1
              }
              detected=$(echo "$detected" | awk '{print $1}')
              if is_ventoy "$detected"; then
                echo "Ventoy already installed on $detected"
                DEVICE="$detected"
              else
                wizard_install "$detected"
                DEVICE="$detected"
              fi
            else
              detected=$(auto_detect_ventoy) || detected=""
              if [[ -z "$detected" ]]; then
                # No Ventoy USB found automatically — look for raw USBs
                local raw_usb
                raw_usb=$(pick_usb) || {
                  echo "Error: No Ventoy USB or removable USB found." >&2
                  echo "Plug in a USB drive and run again, or specify --device /dev/sdX." >&2
                  echo "  Found devices:"
                  lsblk -dno NAME,SIZE,MODEL,RM 2>/dev/null | awk '$4 == "1" {printf "  /dev/%s  %s  %s\n", $1, $2, $3}'
                  exit 1
                }
                detected=$(echo "$raw_usb" | awk '{print $1}')
                echo ""
                echo "Found USB: $(dev_info "$detected")"
                echo "Ventoy is not installed on this device."
                wizard_install "$detected"
                DEVICE="$detected"
              else
                echo "Auto-detected Ventoy USB: $detected"
                DEVICE="$detected"
              fi
            fi
          elif [[ -n "$DEVICE" ]] && [[ $WIZARD_MODE -eq 1 ]]; then
            if ! is_ventoy "$DEVICE"; then
              wizard_install "$DEVICE"
            fi
          fi

          # Step 2: Find data partition and existing mount
          if [[ -n "$DEVICE" ]]; then
            local DATA_PART EXISTING_MOUNT
            DATA_PART=$(find_data_partition "$DEVICE")
            EXISTING_MOUNT=$(find_existing_mount "$DATA_PART")

            if [[ -n "$EXISTING_MOUNT" ]]; then
              MOUNT="$EXISTING_MOUNT"
              echo "Using existing mount: $MOUNT"
            elif [[ $CHECK_ONLY -eq 0 ]]; then
              MOUNT="$MOUNT_POINT"
              mkdir -p "$MOUNT"
              echo "Mounting $DATA_PART to $MOUNT..."
              mount "$DATA_PART" "$MOUNT"
              CLEANUP=1
            elif [[ -z "$MOUNT" ]]; then
              echo "Warning: --check mode but device not mounted. Limited verification." >&2
            fi
          fi

          # Step 3: Verify Ventoy installation
          if [[ -n "$DEVICE" ]]; then
            if ! verify_ventoy "$DEVICE" "$MOUNT"; then
              if [[ $CHECK_ONLY -eq 1 ]]; then
                exit 1
              fi
              echo "Warning: Continuing despite verification issues." >&2
            fi
          fi

          # Step 4: Deploy
          if [[ $CHECK_ONLY -eq 0 ]]; then
            if [[ -z "$MOUNT" ]]; then
              echo "Error: No mount point available for deploy." >&2
              exit 1
            fi
            if deploy_isos "$MOUNT"; then
              echo ""
              echo "Ventoy deploy complete!"
            else
              echo ""
              echo "Deploy completed with errors." >&2
            fi
          fi

          # Step 5: Cleanup
          if [[ $CLEANUP -eq 1 ]]; then
            umount "$MOUNT" || true
            echo "Unmounted $MOUNT"
          fi
        }

        main "$@"
      '';

      ventoy-bundle = pkgs.runCommand "ventoy-bundle" { } ''
        mkdir -p $out/ventoy
        cp "${ventoyJsonFile}" $out/ventoy/ventoy.json
        ${lib.optionalString (vCfg.grubConfig != null) ''
          cp "${vCfg.grubConfig}" $out/ventoy/ventoy_grub.cfg
        ''}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: iso: ''
          TARGET="$out/${iso.target}"
          mkdir -p "$(dirname "$TARGET")"
          ln -s "${iso.source}" "$TARGET"
        '') vCfg.isos)}
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: pkg: let
          profileName = lib.removePrefix "windows-answ-pro-" name;
          target = "/ventoy/scripts/${profileName}.xml";
        in ''
          mkdir -p "$out/ventoy/scripts"
          cp "${pkg}" "$out${target}"
        '') answerFilePackages)}
      '';
    };
    in {
      packages = answerFilePackages // basePackages;
    };
}
