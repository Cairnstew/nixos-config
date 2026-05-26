{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  # Shared option types used in both the flake module and the NixOS sub-module
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
in
{
  options.ventoy = {
    isos = mkOption {
      type = types.attrsOf isoSubmodule;
      default = { };
      description = "ISO entries to deploy to the Ventoy USB.";
    };

    settings = {
      control = mkOption {
        type = types.listOf types.attrs;
        default = [ ];
        description = "Ventoy control settings.";
        example = [
          { VTOY_DEFAULT_MENU_MODE = "0"; }
          { VTOY_TREE_VIEW_MENU_STYLE = "0"; }
          { VTOY_DEFAULT_SEARCH_ROOT = "/iso"; }
        ];
      };

      menu_class = mkOption {
        type = types.listOf (types.submodule {
          options = {
            parent = mkOption { type = types.str; };
            class = mkOption { type = types.str; };
          };
        });
        default = [ ];
        description = "Menu class mappings for CSS theming.";
      };

      theme = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            file = mkOption { type = types.str; };
            display_mode = mkOption { type = types.str; default = "GUI"; };
            gfxmode = mkOption { type = types.str; default = "1920x1080"; };
            fonts = mkOption { type = types.listOf types.str; default = [ ]; };
            font_size = mkOption { type = types.nullOr types.str; default = null; };
          };
        });
        default = null;
        description = "Ventoy theme configuration.";
      };

      persistence = mkOption {
        type = types.listOf (types.submodule {
          options = {
            image = mkOption { type = types.str; };
            backend = mkOption { type = types.str; };
          };
        });
        default = [ ];
        description = "Persistence backend mappings.";
      };

      injection = mkOption {
        type = types.listOf (types.submodule {
          options = {
            image = mkOption { type = types.str; };
            dir = mkOption { type = types.str; };
          };
        });
        default = [ ];
        description = "File injection rules.";
      };

      auto_install = mkOption {
        type = types.listOf (types.submodule {
          options = {
            image = mkOption { type = types.str; };
            template = mkOption { type = types.str; };
          };
        });
        default = [ ];
        description = "Auto-install preseed/kickstart templates.";
      };

      conf_replace = mkOption {
        type = types.listOf (types.submodule {
          options = {
            image = mkOption { type = types.str; };
            file = mkOption { type = types.str; };
          };
        });
        default = [ ];
        description = "GRUB config replacement snippets.";
      };
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Extra ventoy.json keys merged at the top level.";
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
  };

  config.perSystem = { pkgs, ... }:
    let
      vCfg = config.ventoy;

      ventoyJson = {
        control = vCfg.settings.control;
        menu_class = vCfg.settings.menu_class;
        persistence = vCfg.settings.persistence;
        injection = vCfg.settings.injection;
        auto_install = vCfg.settings.auto_install;
        conf_replace = vCfg.settings.conf_replace;
      } // lib.optionalAttrs (vCfg.settings.theme != null) {
        theme = {
          file = vCfg.settings.theme.file;
          display_mode = vCfg.settings.theme.display_mode;
          gfxmode = vCfg.settings.theme.gfxmode;
          fonts = vCfg.settings.theme.fonts;
        } // lib.optionalAttrs (vCfg.settings.theme.font_size != null) {
          font_size = vCfg.settings.theme.font_size;
        };
      } // vCfg.extraConfig;

      ventoyJsonFile = pkgs.writeText "ventoy.json" (builtins.toJSON ventoyJson);

      isoMappings = lib.mapAttrsToList (name: iso:
        "\"${iso.source}|${iso.target}\""
      ) vCfg.isos;
    in
    {
      packages.ventoy-deploy = pkgs.writeShellScriptBin "ventoy-deploy" ''
        set -euo pipefail

        VENTOY_JSON="${ventoyJsonFile}"
        ISO_MAPPINGS=(
          ${lib.concatStringsSep "\n          " isoMappings}
        )

        usage() {
          cat <<'EOF'
        Usage: ventoy-deploy [OPTIONS]

        Deploy Ventoy ISOs and configuration to a Ventoy USB.

        Options:
          -d, --device DEVICE   USB block device (e.g., /dev/sdb)
          -m, --mount PATH      Already-mounted Ventoy data partition
          -h, --help            Show this help

        If neither --device nor --mount is given, tries auto-detection.
        EOF
          exit 0
        }

        DEVICE="${vCfg.device}"
        MOUNT=""
        CLEANUP=0

        while [[ $# -gt 0 ]]; do
          case "$1" in
            -d|--device) DEVICE="$2"; shift 2 ;;
            -m|--mount)  MOUNT="$2";  shift 2 ;;
            -h|--help)   usage ;;
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

        if [[ -z "$DEVICE" ]] && [[ -z "$MOUNT" ]]; then
          VTOY_DEVICE=$(lsblk -o NAME,LABEL -n 2>/dev/null | grep -i "VTOYEFI" | head -1 | awk '{print "/dev/"$1}' | sed 's/[0-9]*$//')
          if [[ -n "$VTOY_DEVICE" ]]; then
            DEVICE="$VTOY_DEVICE"
            echo "Auto-detected Ventoy USB: $DEVICE"
          else
            echo "Error: No Ventoy USB found. Specify --device or --mount." >&2
            exit 1
          fi
        fi

        if [[ -n "$DEVICE" ]]; then
          DATA_PART="''${DEVICE}2"
          MOUNT="${vCfg.mountPoint}"
          mkdir -p "$MOUNT"
          echo "Mounting $DATA_PART to $MOUNT..."
          mount "$DATA_PART" "$MOUNT"
          CLEANUP=1
        fi

        TARGET_VENTOY_DIR="$MOUNT/ventoy"
        mkdir -p "$TARGET_VENTOY_DIR"
        cp "$VENTOY_JSON" "$TARGET_VENTOY_DIR/ventoy.json"
        echo "Deployed ventoy/ventoy.json"

        for mapping in "''${ISO_MAPPINGS[@]}"; do
          IFS='|' read -r source target <<< "$mapping"
          TARGET_DIR="$(dirname "$MOUNT/$target")"
          mkdir -p "$TARGET_DIR"
          echo "Copying $(basename "$source") → $target"
          cp -L "$source" "$MOUNT/$target"
        done

        echo ""
        echo "Ventoy deploy complete!"

        if [[ $CLEANUP -eq 1 ]]; then
          umount "$MOUNT"
          echo "Unmounted $MOUNT"
        fi
      '';

      packages.ventoy-bundle = pkgs.runCommand "ventoy-bundle" { } ''
        mkdir -p $out/ventoy
        cp "${ventoyJsonFile}" $out/ventoy/ventoy.json
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: iso: ''
          TARGET="$out/${iso.target}"
          mkdir -p "$(dirname "$TARGET")"
          ln -s "${iso.source}" "$TARGET"
        '') vCfg.isos)}
      '';
    };
}
