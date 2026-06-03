#!/usr/bin/env bash
set -euo pipefail

# ventoy-deploy — Deploy ISOs + config to a Ventoy USB
#
# All inputs come from environment variables set by the Nix wrapper
# (packages/ventoy-deploy/default.nix). The script is independently
# testable: set the env vars manually and run main "$@".
#
# Usage: ventoy-deploy [OPTIONS] [DEVICE|MOUNT_PATH]

# ── Install/update shell functions ────────────────────────────────────

do_install() {
  local dev="$1" mode="$2"
  local flags=()

  if [[ "${SECURE_BOOT:-0}" == "1" ]]; then flags+=(-s); fi
  if [[ "${GPT:-0}" == "1" ]]; then flags+=(-g); fi
  if [[ "${LABEL:-Ventoy}" != "Ventoy" ]]; then flags+=(-L "${LABEL}"); fi
  if [[ -n "${RESERVE_SIZE_MB:-}" ]]; then flags+=(-r "${RESERVE_SIZE_MB}"); fi

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
  sudo Ventoy2Disk.sh "$cmd" ${flags[@]+"${flags[@]}"} "$dev"
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

# ── Interactive wizard ────────────────────────────────────────────────

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

# ── Help ──────────────────────────────────────────────────────────────

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

# ── Device detection ──────────────────────────────────────────────────

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

  if [[ "${#usbs[@]}" -eq 0 ]]; then
    return 1
  fi

  if [[ "${#usbs[@]}" -eq 1 ]]; then
    echo "${usbs[0]}" | awk '{print $1}'
    return 0
  fi

  echo ""
  echo "Multiple USB drives found. Choose one:"
  for i in "${!usbs[@]}"; do
    echo "  [$((i+1))] ${usbs[$i]}"
  done
  echo ""
  read -p "Select USB [1-${#usbs[@]}]: " choice
  choice=$((choice - 1))
  if [[ $choice -ge 0 ]] && [[ $choice -lt "${#usbs[@]}" ]]; then
    echo "${usbs[$choice]}" | awk '{print $1}'
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

  echo "${dev}2"
}

find_existing_mount() {
  local data_part="$1"
  findmnt -n -o TARGET --source "$data_part" 2>/dev/null || true
}

# ── Verification ──────────────────────────────────────────────────────

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

    if [[ "${#ISO_MAPPINGS[@]}" -gt 0 ]]; then
      for mapping in "${ISO_MAPPINGS[@]}"; do
        local src="${mapping%|*}"
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

# ── Deploy ────────────────────────────────────────────────────────────

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
  cp -L "$VENTOY_JSON" "$ventoy_dir/ventoy.json"
  sync "$ventoy_dir/ventoy.json" 2>/dev/null || sync
  src_size=$(stat -c%s "$VENTOY_JSON" 2>/dev/null || echo 0)
  dest_size=$(stat -c%s "$ventoy_dir/ventoy.json" 2>/dev/null || echo 0)
  if [[ "$src_size" -eq 0 ]] || [[ "$src_size" -ne "$dest_size" ]]; then
    echo "  [FAIL] Failed to deploy ventoy.json" >&2
    errors=1
  else
    echo "  [OK] Deployed ventoy/ventoy.json"
  fi

  # ventoy_grub.cfg (Menu Extension Plugin — F6)
  if [[ -n "${GRUB_CFG:-}" ]] && [[ -f "$GRUB_CFG" ]]; then
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
  for mapping in "${ISO_MAPPINGS[@]}"; do
    IFS='|' read -r source target hash <<< "$mapping"
    local dest="$mount/$target"
    mkdir -p "$(dirname "$dest")"

    # NixOS ISO builder outputs are directories containing iso/*.iso
    if [[ -d "$source" ]] && [[ -z "${source##*.iso}" ]]; then
      local iso_files=( "$source/iso/"*.iso )
      if [[ -f "${iso_files[0]}" ]]; then
        source="${iso_files[0]}"
      fi
    fi

    # Check if hash changed since last deploy (source was rebuilt)
    local prev_hash="${prev_hashes[$target]:-}"
    if [[ -n "$prev_hash" ]] && [[ "$prev_hash" != "$hash" ]]; then
      echo "  [CHANGED] $(basename "$source") (new hash: $hash)"
      changed=1
    fi

    src_size=$(stat -c%s "$source" 2>/dev/null || echo 0)
    dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)

    if [[ -f "$dest" ]] && [[ "$src_size" -eq "$dest_size" ]] && [[ "$changed" -eq 0 ]]; then
      echo "  [SKIP] $(basename "$source") -> $target (up to date, $((src_size / 1024 / 1024))M)"
      echo "${target}|${hash}" >> "$new_state"
      continue
    fi

    echo "  Copying $(basename "$source") -> $target ($((src_size / 1024 / 1024))M)"
    cp -L "$source" "$dest"
    sync "$dest" 2>/dev/null || true

    dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
    if [[ "$src_size" -ne "$dest_size" ]]; then
      echo "  [FAIL] Size mismatch for $target ($src_size vs $dest_size)" >&2
      errors=1
    else
      echo "  [OK] Verified $target ($((src_size / 1024 / 1024))M)"
      echo "${target}|${hash}" >> "$new_state"
    fi
    changed=0
  done

  # Deploy extra files (answer files, scripts, etc.)
  for mapping in "${FILE_MAPPINGS[@]}"; do
    IFS='|' read -r source target hash <<< "$mapping"
    local dest="$mount/$target"
    mkdir -p "$(dirname "$dest")"

    # Check if hash changed
    local prev_hash="${prev_hashes[$target]:-}"
    if [[ -n "$prev_hash" ]] && [[ "$prev_hash" != "$hash" ]]; then
      echo "  [CHANGED] $(basename "$source") (new hash: $hash)"
      changed=1
    fi

    src_size=$(stat -c%s "$source" 2>/dev/null || echo 0)
    dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)

    if [[ -f "$dest" ]] && [[ "$src_size" -eq "$dest_size" ]] && [[ "$changed" -eq 0 ]]; then
      echo "  [SKIP] $(basename "$source") -> $target ($((src_size / 1024))B, up to date)"
      echo "${target}|${hash}" >> "$new_state"
      continue
    fi

    echo "  Copying $(basename "$source") -> $target ($((src_size / 1024))KB)"
    cp -L "$source" "$dest"
    sync "$dest" 2>/dev/null || true

    dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)
    if [[ "$src_size" -ne "$dest_size" ]]; then
      echo "  [FAIL] Size mismatch for $target" >&2
      errors=1
    else
      echo "  [OK] Verified $target ($((src_size / 1024))KB)"
      echo "${target}|${hash}" >> "$new_state"
    fi
    changed=0
  done

  # Preserve entries from previous state not in the current mappings
  # (e.g., installer ISO hash from Step 4). Iterate by reading the
  # new_state file to avoid grep regex issues with path characters.
  for prev_target in "${!prev_hashes[@]}"; do
    local found=false
    while IFS='|' read -r existing_target _; do
      if [[ "$existing_target" == "$prev_target" ]]; then
        found=true
        break
      fi
    done < "$new_state"
    if ! $found; then
      echo "${prev_target}|${prev_hashes[$prev_target]}" >> "$new_state"
    fi
  done

  # Write new state (same filesystem, mv is atomic)
  mv "$new_state" "$state_file"

  return $errors
}

# ── Input validation ─────────────────────────────────────────────────

validate_inputs() {
  local errors=0

  if [[ -z "${VENTOY_JSON:-}" ]] || [[ ! -f "${VENTOY_JSON}" ]]; then
    echo "Error: VENTOY_JSON is unset or not a regular file" >&2
    errors=1
  fi

  if [[ -z "${BUILD_INSTALLER_ISO:-}" ]]; then
    echo "Error: BUILD_INSTALLER_ISO is unset" >&2
    errors=1
  fi

  if [[ $errors -ne 0 ]]; then
    echo "" >&2
    echo "ventoy-deploy reads all configuration from environment variables." >&2
    echo "Run it as the built Nix package (which sets defaults) or manually" >&2
    echo "export the vars listed in packages/ventoy-deploy/default.nix." >&2
    exit 1
  fi
}

# ── Main ──────────────────────────────────────────────────────────────

main() {
  validate_inputs
  local WIZARD_MODE=0
  local CHECK_ONLY=0
  local ASSUME_YES=0
  local DEVICE="$DEFAULT_DEVICE"
  local MOUNT=""
  local CLEANUP=0
  local MODE="deploy"

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

  # ── Install/Update/Info mode ─────────────────────────────────────
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

  # ── Deploy mode ──────────────────────────────────────────────────
  # Step 1: Auto-detect
  if [[ -z "$DEVICE" ]] && [[ -z "$MOUNT" ]]; then
    local detected

    if [[ $WIZARD_MODE -eq 1 ]]; then
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

  # Step 4: Copy pre-built installer ISO (if configured)
  if [[ $BUILD_INSTALLER_ISO -eq 1 ]] && [[ $CHECK_ONLY -eq 0 ]] && [[ -n "${INSTALLER_ISO:-}" ]]; then
    echo ""
    echo "=== Deploying pre-built NixOS installer ISO ==="
    local target="/iso/linux/nixos-installer-x86_64-linux.iso"
    local dest="$MOUNT$target"
    local src_iso=( "$INSTALLER_ISO/iso/"*.iso )
    src_iso="${src_iso[0]}"

    # Derive store hash from INSTALLER_ISO directory path (not the iso filename inside it)
    local src_name src_hash
    src_name=$(basename "$INSTALLER_ISO")
    src_hash="${src_name%%-*}"

    # Check previous state
    local ventoy_dir="$MOUNT/ventoy"
    local state_file="$ventoy_dir/.deploy-state"
    local prev_hash=""
    if [[ -f "$state_file" ]]; then
      while IFS='|' read -r prev_target prev_hash_val; do
        if [[ "$prev_target" == "$target" ]]; then
          prev_hash="$prev_hash_val"
        fi
      done < "$state_file"
    fi

    src_size=$(stat -c%s "$src_iso" 2>/dev/null || echo 0)
    dest_size=$(stat -c%s "$dest" 2>/dev/null || echo 0)

    if [[ -f "$dest" ]] && [[ "$src_size" -eq "$dest_size" ]] && [[ "$src_hash" == "$prev_hash" ]]; then
      echo "  [SKIP] $target (up to date, $((src_size / 1024 / 1024))M)"
    else
      echo "  Copying -> $target"
      mkdir -p "$(dirname "$dest")"
      cp -L "$src_iso" "$dest"
      sync "$dest" 2>/dev/null || sync
      echo "Verifying installer ISO integrity..."
      SRC_HASH=$(sha256sum "$src_iso" | cut -d' ' -f1)
      DST_HASH=$(sha256sum "$dest" | cut -d' ' -f1)
      if [ "$SRC_HASH" != "$DST_HASH" ]; then
          echo "  [FAIL] Installer ISO copy failed integrity check. Removing corrupt file and retrying..."
          rm -f "$dest"
          cp -L "$src_iso" "$dest"
          sync "$dest" 2>/dev/null || sync
          DST_HASH=$(sha256sum "$dest" | cut -d' ' -f1)
          if [ "$SRC_HASH" != "$DST_HASH" ]; then
              echo "  [FAIL] Installer ISO failed integrity check after retry. Aborting."
              exit 1
          fi
      fi
      # Record in state file
      mkdir -p "$ventoy_dir"
      echo "${target}|${src_hash}" >> "$state_file"
      echo "  [OK] Custom ISO deployed and verified ($(stat -c%s "$dest" 2>/dev/null | numfmt --to=iec) MB)"
    fi
  fi

  # Step 5: Deploy ISOs + config
  if [[ $CHECK_ONLY -eq 0 ]]; then
    if [[ -z "$MOUNT" ]]; then
      echo "Error: No mount point available for deploy." >&2
      exit 1
    fi
    if deploy_isos "$MOUNT"; then
      echo ""

      # Step 6: Generate ephemeral Tailscale auth key for installer ISO
      # Uses the Tailscale API with OAuth credentials from agenix.
      # The key is written to the USB's ventoy/ directory; the ISO reads it at boot
      # from the VENTOY data partition.
      if [[ $BUILD_INSTALLER_ISO -eq 1 ]]; then
        local oauth_file="/run/agenix/tailscale-oauthkey"
        if [[ -f "$oauth_file" ]] && command -v curl &>/dev/null && command -v jq &>/dev/null; then
          echo "=== Generating ephemeral Tailscale auth key ==="
          mkdir -p "$MOUNT/ventoy"

          # Source OAuth credentials (TAILSCALE_OAUTH_CLIENT_ID, TAILSCALE_OAUTH_CLIENT_SECRET)
          eval "$(sudo cat "$oauth_file" 2>/dev/null)"

          # Exchange OAuth credentials for an access token
          TOKEN=$(curl -s -d "grant_type=client_credentials" \
            -d "client_id=$TAILSCALE_OAUTH_CLIENT_ID" \
            -d "client_secret=$TAILSCALE_OAUTH_CLIENT_SECRET" \
            -d "scope=devices:create_keys" \
            https://api.tailscale.com/api/v2/oauth/token 2>/dev/null | jq -r '.access_token' 2>/dev/null || true)

          if [[ -n "$TOKEN" ]] && [[ "$TOKEN" != "null" ]]; then
            # Create reusable ephemeral auth key (tag:temp, 7-day expiry)
            # Reusable so the same USB key works across multiple ISO boots.
            # Ephemeral nodes are removed when they disconnect.
            TS_AUTH_KEY=$(curl -s -X POST \
              -H "Authorization: Bearer $TOKEN" \
              -H "Content-Type: application/json" \
              -d '{
                "capabilities": {
                  "devices": {
                    "create": {
                      "reusable": true,
                      "ephemeral": true,
                      "preauthorized": true,
                      "tags": ["tag:temp"]
                    }
                  }
                },
                "expirySeconds": 604800
              }' \
              https://api.tailscale.com/api/v2/tailnet/-/keys 2>/dev/null | jq -r '.key' 2>/dev/null || true)

            if [[ -n "$TS_AUTH_KEY" ]] && [[ "$TS_AUTH_KEY" != "null" ]]; then
              echo "$TS_AUTH_KEY" > "$MOUNT/ventoy/ts.key"
              chmod 600 "$MOUNT/ventoy/ts.key"
              echo "  [OK] Auth key written to /ventoy/ts.key (tag:temp, reusable, 7-day expiry)"
            else
              echo "  [WARN] Failed to generate Tailscale auth key via API."
              echo "  Check that the OAuth key has devices:create_keys scope."
            fi
          else
            echo "  [WARN] Failed to obtain Tailscale OAuth token. Check OAuth credentials."
          fi
        else
          if [[ ! -f "$oauth_file" ]]; then
            echo "  [WARN] OAuth credentials not found at $oauth_file."
          else
            echo "  [WARN] curl or jq not available. Install them to enable auto key generation."
          fi
          echo "  Installer ISO will not auto-connect to Tailscale."
          echo "  Use LAN SSH (root + your SSH key) or run 'tailscale up' manually."
        fi
      fi

      echo "Ventoy deploy complete!"
    else
      echo ""
      echo "Deploy completed with errors." >&2
    fi
  fi

  # Step 7: Cleanup
  if [[ $CLEANUP -eq 1 ]]; then
    umount "$MOUNT" || true
    echo "Unmounted $MOUNT"
  fi
}
