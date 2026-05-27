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
        DEFAULT_DEVICE="${vCfg.device}"
        MOUNT_POINT="${vCfg.mountPoint}"

        CHECK_ONLY=0
        DEVICE="$DEFAULT_DEVICE"
        MOUNT=""
        CLEANUP=0

        usage() {
          cat <<'USAGE'
        Usage: ventoy-deploy [OPTIONS] [DEVICE|MOUNT_PATH]

        Deploy ISOs and ventoy.json to a Ventoy USB, or check an existing installation.

        Options:
          -d, --device DEVICE   USB block device (e.g., /dev/sdb)
          -m, --mount PATH      Already-mounted Ventoy data partition
          -c, --check           Verify Ventoy installation only (no deploy)
          -h, --help            Show this help

        If neither --device nor --mount is given, tries auto-detection.
        USAGE
          exit 0
        }

        auto_detect() {
          local dev labels

          # Prefer removable devices, fall back to all
          for dev in $(lsblk -dno NAME,RM 2>/dev/null | awk '$2 == "1" {print $1}'); do
            dev="/dev/$dev"
            labels=$(lsblk -nlo LABEL "$dev" 2>/dev/null)
            if echo "$labels" | grep -qiE "VTOYEFI|VENTOY"; then
              if command -v ventoy &>/dev/null; then
                if ventoy -l "$dev" &>/dev/null 2>&1; then
                  echo "$dev"
                  return 0
                fi
              else
                echo "$dev"
                return 0
              fi
            fi
          done

          # Fallback: check non-removable devices too
          for dev in $(lsblk -dno NAME,RM 2>/dev/null | awk '$2 != "1" {print $1}'); do
            dev="/dev/$dev"
            labels=$(lsblk -nlo LABEL "$dev" 2>/dev/null)
            if echo "$labels" | grep -qiE "VTOYEFI|VENTOY"; then
              if command -v ventoy &>/dev/null; then
                if ventoy -l "$dev" &>/dev/null 2>&1; then
                  echo "$dev"
                  return 0
                fi
              else
                echo "$dev"
                return 0
              fi
            fi
          done

          return 1
        }

        find_data_partition() {
          local dev="$1" parts part label upper

          # First: look for partition labeled "Ventoy"
          parts=$(lsblk -nlo NAME,LABEL "$dev" 2>/dev/null)
          while IFS=' ' read -r part label _; do
            upper=$(echo "$label" | tr '[:lower:]' '[:upper:]')
            if [[ "$upper" == "VENTOY" ]] && [[ -n "$part" ]]; then
              echo "/dev/$part"
              return 0
            fi
          done <<< "$parts"

          # Second: first non-VTOYEFI partition
          while IFS=' ' read -r part label _; do
            upper=$(echo "$label" | tr '[:lower:]' '[:upper:]')
            if [[ "$upper" != "VTOYEFI" ]] && [[ -n "$part" ]]; then
              echo "/dev/$part"
              return 0
            fi
          done <<< "$parts"

          # Fallback: partition 2 (standard GPT layout)
          echo "''${dev}2"
        }

        find_existing_mount() {
          local data_part="$1"
          findmnt -n -o TARGET --source "$data_part" 2>/dev/null || true
        }

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

        deploy_isos() {
          local mount="$1" errors=0 src_size dest_size
          local ventoy_dir="$mount/ventoy"

          mkdir -p "$ventoy_dir"
          cp "$VENTOY_JSON" "$ventoy_dir/ventoy.json"
          src_size=$(stat -c%s "$VENTOY_JSON" 2>/dev/null || echo 0)
          dest_size=$(stat -c%s "$ventoy_dir/ventoy.json" 2>/dev/null || echo 0)
          if [[ "$src_size" -eq 0 ]] || [[ "$src_size" -ne "$dest_size" ]]; then
            echo "  [FAIL] Failed to deploy ventoy.json" >&2
            return 1
          fi
          echo "  [OK] Deployed ventoy/ventoy.json"

          for mapping in "''${ISO_MAPPINGS[@]}"; do
            IFS='|' read -r source target <<< "$mapping"
            local dest="$mount/$target"
            mkdir -p "$(dirname "$dest")"

            src_size=$(stat -c%s "$source" 2>/dev/null || echo 0)
            echo "  Copying $(basename "$source") -> $target"
            cp -L "$source" "$dest"

            dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
            if [[ "$src_size" -ne "$dest_size" ]]; then
              echo "  [FAIL] Size mismatch for $target ($src_size vs $dest_size)" >&2
              errors=1
            else
              echo "  [OK] Verified $target ($((src_size / 1024 / 1024))M)"
            fi
          done

          return $errors
        }

        main() {
          while [[ $# -gt 0 ]]; do
            case "$1" in
              -d|--device) DEVICE="$2"; shift 2 ;;
              -m|--mount)  MOUNT="$2";  shift 2 ;;
              -c|--check)  CHECK_ONLY=1; shift ;;
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

          # --- Step 1: Auto-detect ---
          if [[ -z "$DEVICE" ]] && [[ -z "$MOUNT" ]]; then
            local detected
            detected=$(auto_detect) || {
              echo "Error: No Ventoy USB found. Specify --device or --mount." >&2
              exit 1
            }
            DEVICE="$detected"
            echo "Auto-detected Ventoy USB: $DEVICE"
          fi

          # --- Step 2: Find data partition and existing mount ---
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

          # --- Step 3: Verify Ventoy installation ---
          if ! verify_ventoy "$DEVICE" "$MOUNT"; then
            if [[ $CHECK_ONLY -eq 1 ]]; then
              exit 1
            fi
            echo "Warning: Continuing despite verification issues." >&2
          fi

          # --- Step 4: Deploy ---
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

          # --- Step 5: Cleanup ---
          if [[ $CLEANUP -eq 1 ]]; then
            umount "$MOUNT" || true
            echo "Unmounted $MOUNT"
          fi
        }

        main "$@"
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
