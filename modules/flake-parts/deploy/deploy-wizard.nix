{ inputs, lib, ... }: {
  perSystem = { pkgs, system, ... }: lib.optionalAttrs (builtins.elem system [ "x86_64-linux" "aarch64-linux" ]) {
    apps.deploy-wizard = {
      type = "app";
      program = pkgs.writeShellApplication {
        name = "deploy-nixos-wizard";
        runtimeInputs = [
          inputs.nixos-anywhere.packages.${system}.default
          pkgs.openssh
          pkgs.tailscale
          pkgs.whois
        ];
        checkPhase = "";
        text = ''
                    set -euo pipefail

                    # ── Help / Usage ──────────────────────────────────────────

                    if [ $# -lt 1 ]; then
                      echo "Usage: deploy-nixos-wizard <hostname>"
                      echo ""
                      echo "Interactive wizard: SSH into a NixOS live ISO via"
                      echo "Tailscale, inspect disks, prepare partitions, deploy."
                      exit 1
                    fi

                    HOST="$1"
                    FLAKE_DIR="$PWD"
                    HOST_DIR="$FLAKE_DIR/configurations/nixos/$HOST"
                    DISK_CONFIG="$HOST_DIR/disk-config.nix"
                    SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"

                    warn() { printf "\033[33m%s\033[0m\n" "$*"; }
                    ok()   { printf "\033[32m%s\033[0m\n" "$*"; }
                    info() { printf "\033[36m%s\033[0m\n" "$*"; }
                    ssh_iso() { ssh $SSH_OPTS "$TAILSCALE_HOST" "$@"; }

                    # ── 1. Connect to target via Tailscale ───────────────────

                    info "Resolving nixos Tailscale IP ..."
                    TS_IP=$(tailscale status 2>/dev/null | awk '/^100\./ && $2 == "nixos" {print $1}')
                    if [ -z "$TS_IP" ]; then
                      echo "Cannot find 'nixos' node in tailscale status."
                      echo "Boot the live ISO and make sure it is connected to your tailnet."
                      exit 1
                    fi
                    TAILSCALE_HOST="nixos@$TS_IP"

                    echo ""
                    info "======================================================"
                    info "  NixOS Deploy Wizard — $HOST"
                    info "======================================================"
                    echo ""

                    info "Testing connection to $TAILSCALE_HOST ..."
                    if ! ssh_iso "echo connected" >/dev/null 2>&1; then
                      echo "Cannot reach $TAILSCALE_HOST. Is the live ISO booted and on Tailscale?"
                      exit 1
                    fi
                    ok "Connected to $TAILSCALE_HOST"

                    info "Resolving local IP for direct SSH ..."
                    local_ip=$(ssh_iso "hostname -I | awk '{print \$1}'")
                    DEPLOY_ADDR="root@$local_ip"
                    ok "Deploy target: $DEPLOY_ADDR"

                    # ── 2. Select a disk ────────────────────────────────────

                    select_disk() {
                      local disks=()
                      local i=0
                      while IFS= read -r line; do
                        disks+=("$line")
                      done < <(ssh_iso "lsblk -nd -o NAME,SIZE,TYPE,MODEL" 2>/dev/null)
                      if [ "''${#disks[@]}" -eq 0 ]; then
                        echo "No disks found on target." >&2
                        exit 1
                      fi
                      echo "" >&2
                      for ((i=0; i<''${#disks[@]}; i++)); do
                        printf "  \033[36m%2d\033[0m) /dev/%s\n" $((i+1)) "''${disks[$i]}" >&2
                      done
                      echo "" >&2
                      while true; do
                        printf "Select disk number [1-%d]: " "''${#disks[@]}" >&2
                        read -r sel </dev/tty
                        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "''${#disks[@]}" ]; then
                          local name
                          name=$(echo "''${disks[$((sel-1))]}" | awk '{print $1}')
                          echo "/dev/$name"
                          return
                        fi
                      done
                    }

                    echo ""
                    info "Available disks:"
                    disk_dev=$(select_disk)
                    ok "Selected disk: $disk_dev"

                    # ── 3. Show partition table ──────────────────────────────

                    echo ""
                    info "Partition table for $disk_dev:"
                    # shellcheck disable=SC2029
                    ssh_iso "sudo lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTTYPE,MOUNTPOINT -n $disk_dev 2>/dev/null || sudo sgdisk -p $disk_dev 2>/dev/null || sudo fdisk -l $disk_dev"
                    echo ""

                    # ── 4. Detect actual partitions by type ─────────────────

                    # Return the /dev/X node of the first partition matching
                    # the given GPT type GUID (partial match).
                    find_part_by_gpt_type() {
                      local type_guid="$1"
                      local name
                      name=$(ssh_iso "sudo lsblk -lno NAME,PARTTYPE -n $disk_dev 2>/dev/null" 2>/dev/null \
                        | awk -v t="$type_guid" 'tolower($2) ~ tolower(t) {print $1; exit}')
                      if [ -n "$name" ]; then
                        echo "/dev/$name"
                      fi
                    }

                    find_part_by_fstype() {
                      local fstype="$1"
                      local name
                      name=$(ssh_iso "lsblk -lno NAME,FSTYPE -n $disk_dev 2>/dev/null" 2>/dev/null \
                        | awk -v t="$fstype" '$2 == t {print $1; exit}')
                      if [ -n "$name" ]; then
                        echo "/dev/$name"
                      fi
                    }

                    find_part_by_label() {
                      local label="$1"
                      local name
                      name=$(ssh_iso "lsblk -lno NAME,LABEL -n $disk_dev 2>/dev/null" 2>/dev/null \
                        | awk -v t="$label" 'toupper($2) == toupper(t) {print $1; exit}')
                      if [ -n "$name" ]; then
                        echo "/dev/$name"
                      fi
                    }

                    # ── 5. Present a decision tree ─────────────────────────

                    ESP_GUID="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
                    MSR_GUID="e3c9e316-31b4-4298-89fa-94c9f823f8a5"
                    LINUX_GUID="0fc63daf-8483-4772-8e79-3d69d8477de4"
                    WINDOWS_GUID="ebd0a0a2-b9e5-4433-87c0-68b6b72699c7"

                    detect_existing_nixos_part() {
                      # Try label first, then Linux GPT type, then ext4 (broad fallback)
                      local part
                      part=$(find_part_by_label "nixos")
                      [ -z "$part" ] && part=$(find_part_by_gpt_type "$LINUX_GUID")
                      [ -z "$part" ] && part=$(find_part_by_fstype "ext4")
                      echo "$part"
                    }

                    nixos_part=""
                    create_mode="mount"

                    if [ -f "$DISK_CONFIG" ]; then
                      ok "Found disk-config.nix for $HOST"
                    fi

                    info "Checking for existing NixOS partition ..."
                    existing_nixos=$(detect_existing_nixos_part)

                    if [ -n "$existing_nixos" ]; then
                      ok "Found existing NixOS partition: $existing_nixos"
                      printf "Reuse it? [Y/n]: "
                      read -r reuse </dev/tty
                      if [[ "$reuse" =~ ^[Nn] ]]; then
                        existing_nixos=""
                      fi
                    fi

                    if [ -n "$existing_nixos" ]; then
                      nixos_part="$existing_nixos"
                      create_mode="mount"
                    else
                      # No existing NixOS partition.  Check for free space.
                      echo ""
                      info "Checking for unallocated space on $disk_dev ..."
                      free_info=$(ssh_iso "sudo sgdisk -p $disk_dev 2>/dev/null | grep -i 'free\|unallocated' | head -1" || true)

                      has_free=false
                      if echo "$free_info" | grep -qiP '\d+\s+(GiB|MiB|TiB)'; then
                        has_free=true
                      fi

                      if $has_free; then
                        info "Unallocated space found: $(echo "$free_info" | awk '{$1=$1; print}')"
                        printf "Create a NixOS partition in free space? [Y/n]: "
                        read -r create </dev/tty
                        if [[ "$create" =~ ^[Nn] ]]; then
                          echo ""
                          printf "Enter existing partition device (e.g., /dev/sda4): "
                          read -r manual_part </dev/tty
                          nixos_part="$manual_part"
                          create_mode="mount"
                        else
                          printf "Partition size (e.g., 50G, or Enter for remaining space): "
                          read -r part_size </dev/tty
                          echo ""
                          info "Creating partition on $disk_dev ..."
                          if [ -z "$part_size" ]; then
                            ssh_iso "sudo sgdisk -n 0:0:0 -t 0:8300 -c 0:nixos $disk_dev" >/dev/null 2>&1
                          else
                            ssh_iso "sudo sgdisk -n 0:0:+$part_size -t 0:8300 -c 0:nixos $disk_dev" >/dev/null 2>&1
                          fi
                          new_part_name=$(ssh_iso "lsblk -ln -o NAME $disk_dev 2>/dev/null | tail -1")
                          if [ -n "$new_part_name" ]; then
                            nixos_part="/dev/$new_part_name"
                          else
                            echo ""
                            ssh_iso "lsblk -o NAME,SIZE,FSTYPE -n $disk_dev" >&2
                            printf "Enter the new partition device (e.g., /dev/sda4): "
                            read -r nixos_part </dev/tty
                          fi
                          info "Formatting $nixos_part as ext4 ..."
                          ssh_iso "sudo mkfs.ext4 -L nixos $nixos_part" >/dev/null 2>&1
                          ssh_iso "sudo partprobe $disk_dev 2>/dev/null || true"
                          ok "Partition $nixos_part created and formatted"
                          create_mode="mount"
                        fi
                      else
                        info "No unallocated space detected."
                        info "Existing partitions on $disk_dev:"
                        ssh_iso "lsblk -o NAME,SIZE,FSTYPE,LABEL -n $disk_dev"
                        echo ""
                        printf "Enter the partition to use for NixOS (e.g., /dev/sda4): "
                        read -r nixos_part </dev/tty
                        if [ -n "$nixos_part" ]; then
                          printf "Format it? [y/N]: "
                          read -r fmt </dev/tty
                          if [[ "$fmt" =~ ^[Yy] ]]; then
                            info "Formatting $nixos_part as ext4 ..."
                            ssh_iso "sudo umount $nixos_part 2>/dev/null || true; sudo mkfs.ext4 -F -L nixos $nixos_part" >/dev/null 2>&1
                            ok "Formatted $nixos_part"
                          fi
                          create_mode="mount"
                        fi
                      fi
                    fi

                    if [ -z "$nixos_part" ]; then
                      echo "No target partition selected. Aborting."
                      exit 1
                    fi
                    ok "Target NixOS partition: $nixos_part (mode: $create_mode)"

                    # ── 7. Dynamic GPT partlabel renaming ──────────────────

                    # Map actual partitions to the names disko expects:
                    #   disk-main-ESP, disk-main-msr, disk-main-windows, disk-main-nixos
                    # Instead of hardcoding partition numbers 1/2/3/4, we find
                    # each partition by its GPT type GUID or label, then rename
                    # by partition number.

                    echo ""
                    info "Mapping partition labels for disko ..."

                    map_label() {
                      local disko_name="$1"  # e.g. "ESP", "msr", "windows", "nixos"
                      local type_guid="$2"
                      local fallback_fstype="$3"
                      local fallback_label="$4"

                      local part=""
                      # Try GPT type GUID match first
                      if [ -n "$type_guid" ]; then
                        part=$(find_part_by_gpt_type "$type_guid")
                      fi
                      # Fall back to filesystem type
                      if [ -z "$part" ] && [ -n "$fallback_fstype" ]; then
                        part=$(find_part_by_fstype "$fallback_fstype")
                      fi
                      # Fall back to label
                      if [ -z "$part" ] && [ -n "$fallback_label" ]; then
                        part=$(find_part_by_label "$fallback_label")
                      fi

                      if [ -n "$part" ]; then
                        local num
                        num=$(echo "$part" | grep -oP '\d+$')
                        if [ -n "$num" ]; then
                          info "  $disko_name → $part (partition $num)"
                          ssh_iso "sudo sgdisk -c $num:disk-main-$disko_name $disk_dev" >/dev/null 2>&1
                          return 0
                        fi
                      fi
                      warn "  $disko_name: not found (will be skipped)"
                      return 1
                    }

                    # Map known partitions.  Always map the NixOS partition
                    # (which we just created / selected).
                    nixos_num=$(echo "$nixos_part" | grep -oP '\d+$')
                    if [ -n "$nixos_num" ]; then
                      info "  nixos → $nixos_part (partition $nixos_num)"
                      ssh_iso "sudo sgdisk -c $nixos_num:disk-main-nixos $disk_dev" >/dev/null 2>&1
                    fi

                    map_label "ESP"    "$ESP_GUID"    "vfat" "ESP"
                    map_label "msr"    "$MSR_GUID"    ""     ""
                    map_label "windows" "$WINDOWS_GUID" "ntfs" "Windows"

                    ssh_iso "sudo partprobe $disk_dev 2>/dev/null || true"
                    ok "Partition labels updated"

                    # ── 8. Set password (optional) ─────────────────────────

                    echo ""
                    read -s -p "Set password for seanc (leave blank to skip): " user_password
                    echo
                    extra_module=""
                    extra_module_arg=""
                    if [ -n "$user_password" ]; then
                      hashed_password=$(echo "$user_password" | mkpasswd -m sha-512 -s)
                      extra_module=$(mktemp /tmp/nixos-password-XXXXXX.nix)
                      cat > "$extra_module" << EOF
          { ... }: {
            users.users.seanc.hashedPassword = "$hashed_password";
          }
          EOF
                      extra_module_arg="--extra-nixos-module $extra_module"
                    fi

                    # ── 9. Deploy ──────────────────────────────────────────

                    echo ""
                    ok "Ready to deploy NixOS to $nixos_part"
                    printf "Continue? [y/N]: "
                    read -r confirmed </dev/tty
                    if [[ ! "$confirmed" =~ ^[Yy] ]]; then
                      echo "Aborting."
                      exit 1
                    fi

                    info "Deploying $HOST via nixos-anywhere ..."
                    info "Target: $DEPLOY_ADDR"
                    info "Mode: --disko-mode $create_mode"

                    # shellcheck disable=SC2086
                    exec nix run "$FLAKE_DIR#deploy" -- "$HOST" "$DEPLOY_ADDR" $extra_module_arg --disko-mode "$create_mode"
        '';
      };
      meta.description = "Interactive deploy wizard: SSH into live ISO, inspect disks, prepare NixOS partition, deploy via nixos-anywhere";
    };
  };
}
