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
  pluginOptionTypes = {
    control = types.listOf types.attrs;
    theme = types.nullOr (types.submodule themeSubmodule);
    menu_class = types.listOf menuClassSubmodule;
    persistence = types.listOf persistenceSubmodule;
    injection = types.listOf injectionSubmodule;
    auto_install = types.listOf autoInstallSubmodule;
    conf_replace = types.listOf confReplaceSubmodule;
    menu_alias = types.listOf menuAliasSubmodule;
    menu_tip = types.nullOr (types.submodule menuTipSubmodule);
    image_list = types.listOf types.str;
    image_blacklist = types.listOf types.str;
    password = types.attrs;
    dud = types.listOf dudSubmodule;
    wimboot = types.listOf wimbootSubmodule;
    vhdboot = types.listOf vhdbootSubmodule;
    vtoyboot = types.listOf vtoybootSubmodule;
    auto_memdisk = types.listOf types.str;
  };

  modeSuffixes = [ "" "legacy" "uefi" "ia32" "aa64" "mips" ];

  pluginDescriptions = {
    control = "Global control settings";
    theme = "Theme configuration";
    menu_class = "Menu class mappings for CSS theming";
    persistence = "Persistence backend mappings";
    injection = "File injection rules";
    auto_install = "Auto-install preseed/kickstart templates";
    conf_replace = "GRUB config replacement snippets";
    menu_alias = "Menu alias definitions (friendly names)";
    menu_tip = "Menu tip configuration";
    image_list = "Image whitelist — only listed files shown in menu";
    image_blacklist = "Image blacklist — hide listed files from menu";
    password = "Password protection settings (use with caution — stored in /nix/store)";
    dud = "Driver Update Disk mappings (RHEL/CentOS/SUSE)";
    wimboot = "Wimboot configuration";
    vhdboot = "Windows VHD/VHDX boot configuration";
    vtoyboot = "Linux vDisk boot configuration";
    auto_memdisk = "Image paths to auto-boot in Memdisk mode";
  };

  modeDescriptions = {
    "" = "all boot modes";
    legacy = "x86 Legacy BIOS mode";
    uefi = "x86_64 UEFI mode";
    ia32 = "IA32 UEFI mode";
    aa64 = "ARM64 UEFI mode";
    mips = "MIPS64 UEFI mode";
  };

  pluginDefaults = {
    control = [ ];
    theme = null;
    menu_class = [ ];
    persistence = [ ];
    injection = [ ];
    auto_install = [ ];
    conf_replace = [ ];
    menu_alias = [ ];
    menu_tip = null;
    image_list = [ ];
    image_blacklist = [ ];
    password = { };
    dud = [ ];
    wimboot = [ ];
    vhdboot = [ ];
    vtoyboot = [ ];
    auto_memdisk = [ ];
  };

  pluginOptions = lib.listToAttrs (lib.flatten (lib.mapAttrsToList
    (name: optType:
      map
        (suffix:
          let
            key = if suffix == "" then name else "${name}_${suffix}";
          in
          {
            name = key;
            value = mkOption {
              type = optType;
              default = pluginDefaults.${name};
              description = "${pluginDescriptions.${name}}. Applied in ${modeDescriptions.${suffix}}.";
            };
          })
        modeSuffixes
    )
    pluginOptionTypes));

in
{
  options.ventoy = {
    _internal = {
      pluginNames = mkOption {
        type = types.listOf types.str;
        internal = true;
        readOnly = true;
        default = builtins.attrNames pluginOptionTypes;
        description = "Plugin attribute names used for ventoy.json generation.";
      };
      modeSuffixes = mkOption {
        type = types.listOf types.str;
        internal = true;
        readOnly = true;
        default = [ "" "legacy" "uefi" "ia32" "aa64" "mips" ];
        description = "BIOS mode suffixes for plugin options.";
      };
    };
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

    answerFileSettings = {
      username = mkOption {
        type = types.str;
        default = "user";
        description = "Default local account username for generated answer files.";
      };
      hostname = mkOption {
        type = types.str;
        default = "HOST-####";
        description = "Default computer name pattern for generated answer files.";
      };
      password = mkOption {
        type = types.str;
        default = "password";
        description = "Default local account password for generated answer files.";
      };
      extraFlags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra GenerateAnswerFile flags appended to all answer file profiles.";
      };
      diskId = mkOption {
        type = types.str;
        default = "0";
        description = "Target disk ID for Windows installation. Run `lsblk` from a live NixOS USB to find yours. When booting from Ventoy, the internal drive is usually 1.";
        example = "1";
      };
    };
  };
}
