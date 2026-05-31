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

                    if [ $# -lt 1 ]; then
                      echo "Usage: deploy-nixos-wizard <hostname>"
                      echo ""
                      echo "Connects to the host's live ISO via Tailscale,"
                      echo "helps select/create a partition, then deploys."
                      exit 1
                    fi

                    HOST="$1"
                    FLAKE_DIR="$PWD"
                    DISK_CONFIG="$FLAKE_DIR/configurations/nixos/$HOST/disk-config.nix"
                    SSH_OPTS="-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5"

                    warn() { printf "\033[33m⚠️  %s\033[0m\n" "$*"; }
                    ok()   { printf "\033[32m✓ %s\033[0m\n" "$*"; }
                    info() { printf "\033[36m%s\033[0m\n" "$*"; }
                    ssh_iso() { ssh $SSH_OPTS "$TAILSCALE_HOST" "$@"; }

                    info "🔍 Resolving nixos Tailscale IP ..."
                    TS_IP=$(tailscale status 2>/dev/null | awk '/^100\./ && $2 == "nixos" {print $1}')
                    if [ -z "$TS_IP" ]; then
                      echo "❌ Cannot find nixos node in tailscale status — is the live ISO booted and on Tailscale?"
                      exit 1
                    fi
                    TAILSCALE_HOST="nixos@$TS_IP"

                    # Fetch disk list from target, show numbered menu, return selected /dev/X
                    select_disk() {
                      local disks=()
                      local i=0
                      while IFS= read -r line; do
                        disks+=("$line")
                      done < <(ssh_iso "lsblk -nd -o NAME,SIZE,TYPE,MODEL" 2>/dev/null)
                      if [ "''${#disks[@]}" -eq 0 ]; then
                        echo "❌ No disks found on target." >&2
                        exit 1
                      fi
                      echo "" >&2
                      for ((i=0; i<''${#disks[@]}; i++)); do
                        printf "  \033[36m%2d\033[0m) /dev/%s\n" $((i+1)) "''${disks[$i]}" >&2
                      done
                      echo "" >&2
                      while true; do
                        printf "💾 Select disk number [1-%d]: " "''${#disks[@]}" >&2
                        read -r sel </dev/tty
                        if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le "''${#disks[@]}" ]; then
                          local name
                          name=$(echo "''${disks[$((sel-1))]}" | awk '{print $1}')
                          echo "/dev/$name"
                          return
                        fi
                      done
                    }

                    cleanup() {
                      [ -n "''${TMPDIR:-}" ] && rm -rf "$TMPDIR"
                      [ -n "''${extra_module:-}" ] && rm -f "$extra_module"
                    }
                    trap cleanup EXIT

                    echo ""
                    info "════════════════════════════════════════════════════"
                    info "  NixOS Deploy Wizard — $HOST"
                    info "════════════════════════════════════════════════════"
                    echo ""

                    info "🔍 Testing connection to $TAILSCALE_HOST ..."
                    if ! ssh_iso "echo connected" >/dev/null 2>&1; then
                      echo "❌ Cannot reach $TAILSCALE_HOST — is the live ISO booted and on Tailscale?"
                      exit 1
                    fi
                    ok "Connected to $TAILSCALE_HOST"

                    info "🔍 Resolving local IP for direct SSH ..."
                    local_ip=$(ssh_iso "hostname -I | awk '{print \$1}'")
                    DEPLOY_ADDR="root@$local_ip"
                    ok "Deploy target: $DEPLOY_ADDR"

                    FLAKE_DIR="$PWD"

                    if [ -f "$DISK_CONFIG" ]; then
                      info "📋 Found disk-config.nix"
                    fi
                    info "📋 Interactive partition setup"
                    echo ""
                    disk_dev=$(select_disk)
                    echo ""

                    info "📊 Partition table for $disk_dev:"
                    ssh_iso "sudo sgdisk -p $disk_dev || sudo parted $disk_dev print || sudo fdisk -l $disk_dev"
                    echo ""

                    existing_line=$(ssh_iso "lsblk -l -o NAME,FSTYPE,LABEL -n $disk_dev 2>/dev/null | grep -iE 'ext4.*nixos|nixos.*ext4' | head -1")
                    existing_dev=""
                    existing_dev_path=""
                    if [ -n "$existing_line" ]; then
                      existing_dev=$(echo "$existing_line" | awk '{print $1}')
                      existing_dev_path="/dev/$existing_dev"
                      ok "Found existing NixOS partition: $existing_dev_path"
                      printf "Reuse it? [Y/n]: "
                      read -r reuse
                      if [[ "$reuse" =~ ^[Nn] ]]; then
                        existing_dev=""
                      fi
                    fi

                    if [ -z "$existing_dev" ]; then
                      free_info=$(ssh_iso "sudo sgdisk -p $disk_dev 2>/dev/null | grep -i 'free\|unallocated' | head -1" || true)
                      free_bytes=$(echo "$free_info" | grep -oP '[\d.]+ \K(GiB|MiB|KiB)' || true)
                      has_room=false
                      case "$free_bytes" in
                        GiB) has_room=true ;;
                        MiB)
                          size_val=$(echo "$free_info" | grep -oP '[\d.]+(?= MiB)')
                          if [ -n "$size_val" ] && [ "$(echo "$size_val >= 1" | bc -l 2>/dev/null || echo 0)" = 1 ]; then
                            has_room=true
                          fi
                          ;;
                      esac
                      if [ -n "$free_info" ] && $has_room; then
                        echo ""
                        info "Found unallocated space: $free_info"
                        printf "Create NixOS partition? [Y/n]: "
                        read -r create
                        if [[ "$create" =~ ^[Nn] ]]; then
                          echo "❌ Aborting. Create the partition manually and re-run."
                          exit 1
                        fi
                        printf "Partition size (e.g., 50G, or press Enter for 100%% of free space): "
                        read -r part_size
                        echo ""
                        info "Creating partition on $disk_dev ..."
                        if [ -z "$part_size" ]; then
                          ssh_iso "sudo sgdisk -n 0:0:0 -t 0:8300 -c 0:nixos $disk_dev"
                        else
                          ssh_iso "sudo sgdisk -n 0:0:+$part_size -t 0:8300 -c 0:nixos $disk_dev"
                        fi
                        part_name=$(ssh_iso "lsblk -l -n -o NAME $disk_dev 2>/dev/null | grep -v '^$' | tail -1")
                        if [ -z "$part_name" ]; then
                          echo ""
                          info "Created partition. Listing current partitions:"
                          ssh_iso "lsblk -l -o NAME,SIZE,FSTYPE -n $disk_dev"
                          echo ""
                          printf "Enter the new partition device (e.g., /dev/sda4): "
                          read -r nixos_part
                        else
                          nixos_part="/dev/$part_name"
                        fi
                        info "Formatting $nixos_part as ext4 (label: nixos) ..."
                        ssh_iso "sudo mkfs.ext4 -L nixos $nixos_part" >/dev/null 2>&1
                        ok "Partition $nixos_part created and formatted"
                        ssh_iso "sudo partprobe $disk_dev 2>/dev/null || true"
                      else
                        echo ""
                        if [ -n "$existing_dev_path" ]; then
                          warn "Only $free_info free — not enough for a new partition."
                          nixos_part="$existing_dev_path"
                          printf "Wipe and reformat existing NixOS partition ($nixos_part)? [y/N]: "
                          read -r wipe
                          if [[ "$wipe" =~ ^[Yy] ]]; then
                            info "Wiping $nixos_part ..."
                            ssh_iso "sudo umount $nixos_part 2>/dev/null || true; sudo mkfs.ext4 -F -L nixos $nixos_part"
                            ok "Reformatted $nixos_part"
                          fi
                        else
                          warn "No unallocated space detected."
                          info "Existing partitions:"
                          ssh_iso "lsblk -l -o NAME,SIZE,FSTYPE,LABEL -n $disk_dev"
                          echo ""
                          printf "Enter existing NixOS partition device (e.g., /dev/sda4): "
                          read -r nixos_part
                        fi
                      fi
                    else
                      nixos_part="/dev/$existing_dev"
                    fi

                    echo ""
                    warn "Your host config ($HOST) may have a hardcoded nixosPartition."
                    warn "Ensure configurations/nixos/$HOST/default.nix has:"
                    warn "  my.disko.dualBoot.nixosPartition = \"$nixos_part\";"
                    echo ""
                    printf "Continue deployment? [y/N]: "
                    read -r confirmed
                    if [[ ! "$confirmed" =~ ^[Yy] ]]; then
                      echo "❌ Aborting. Update the config and re-run."
                      exit 1
                    fi

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

                    echo ""
                    ok "Deploying NixOS to $nixos_part (useExisting mode) ..."

                    part_num="''${nixos_part##*[!0-9]}"
                    info "Renaming partlabels to match disko expectations (disk-main-*) ..."
                    ssh_iso "sudo sgdisk -c 1:disk-main-ESP -c 2:disk-main-msr -c 3:disk-main-windows -c $part_num:disk-main-nixos $disk_dev" >/dev/null 2>&1
                    ssh_iso "sudo partprobe $disk_dev 2>/dev/null || true"

                    # shellcheck disable=SC2086
                    nix run "$FLAKE_DIR#deploy" -- "$HOST" "$DEPLOY_ADDR" $extra_module_arg --disko-mode mount
        '';
      };
      meta.description = "Interactive deploy wizard: SSH into live ISO, pick/partition disk, install NixOS";
    };
  };
}
