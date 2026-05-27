{ writeShellApplication, utillinux, e2fsprogs, gptfdisk, ntfs3g, coreutils, gnugrep, gawk, systemd, jq }:

writeShellApplication {
  name = "detect-dualboot";
  meta = {
    description = "Detect Windows + ESP partitions and output dual-boot Nix config snippet";
    mainProgram = "detect-dualboot";
  };
  runtimeInputs = [ utillinux e2fsprogs gptfdisk ntfs3g coreutils gnugrep gawk systemd jq ];
  text = ''
    set -euo pipefail

    bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
    green() { printf "\033[32m%s\033[0m\n" "$*"; }
    yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
    red()   { printf "\033[31m%s\033[0m\n" "$*" >&2; }

    if [[ $EUID -ne 0 ]]; then
      red "Must be run as root (needs raw disk access)."
      exit 1
    fi

    bold "Dual-boot Detection Tool"
    echo "Scanning disks for Windows + ESP partitions..."
    echo

    found_any=false

    for disk_dev in /dev/sd? /dev/nvme?n? /dev/mmcblk? /dev/vd? /dev/nvme?n?; do
      [[ -b "$disk_dev" ]] || continue

      disk="$disk_dev"

      # Determine partition naming suffix
      if echo "$disk" | grep -qP 'nvme|mmcblk|loop'; then
        psuf="p"
      else
        psuf=""
      fi

      info=$(lsblk "$disk" -Jpo NAME,SIZE,TYPE,FSTYPE,LABEL,PARTTYPE 2>/dev/null) || continue

      esp_part=""
      win_part=""
      win_size=""
      win_label=""

      while IFS="|" read -r dev _ fstype label parttype; do
        [[ -z "$dev" || "$dev" == "null" ]] && continue
        upper=$(echo "$parttype" | tr '[:lower:]' '[:upper:]')

        # ESP check: vfat + EF00 type
        if [[ "$fstype" == "vfat" && "$upper" == "C12A7328-F81F-11D2-BA4B-00A0C93EC93B" ]]; then
          mnt=$(mktemp -d)
          if mount "$dev" "$mnt" 2>/dev/null; then
            if [[ -f "$mnt/EFI/Microsoft/Boot/bootmgfw.efi" ]]; then
              esp_part="$dev"
            fi
            umount "$mnt" 2>/dev/null || true
          fi
          rmdir "$mnt" 2>/dev/null || true
        fi

        # Windows check: NTFS + Microsoft Basic Data + >20GB
        if [[ "$fstype" == "ntfs" && "$upper" == "EBD0A0A2-B9E5-4433-87C0-68B6B72699C7" ]]; then
          bytes=$(lsblk -bno SIZE "$dev" 2>/dev/null || echo 0)
          if (( bytes > 20 * 1024 * 1024 * 1024 )); then
            mnt2=$(mktemp -d)
            if mount -t ntfs-3g "$dev" "$mnt2" 2>/dev/null; then
              if [[ -d "$mnt2/Windows/System32" ]]; then
                win_part="$dev"
                win_size=$(numfmt --to=iec-i "$bytes" 2>/dev/null || echo "''${bytes}B")
                win_label="$label"
              fi
              umount "$mnt2" 2>/dev/null || true
            fi
            rmdir "$mnt2" 2>/dev/null || true
          fi
        fi
      done < <(echo "$info" | jq -r '
        .blockdevices[0].children[]? //
        .blockdevices[] |
        [.name, .size//"0", .fstype//"", .label//"", .parttype//""] |
        @tsv
      ' 2>/dev/null | sed 's/\t/|/g')

      # Aggregate free space
      used_bytes=$(lsblk -bno SIZE "$disk" 2>/dev/null | awk '{s+=$1} END {print s}' || echo 0)

      if [[ -n "$win_part" ]]; then
        found_any=true
        bold "=== Found on $disk ==="
        printf "  %-18s %s\n" "Windows:" "$win_part  ($win_size, $win_label)"
        printf "  %-18s %s\n" "ESP:" "''${esp_part:-not found}"
        printf "  %-18s %s\n" "Free space:" "$(numfmt --to=iec-i "$used_bytes" 2>/dev/null || echo unknown)"
        echo
        green "# Paste this into your host config (fix nixosPartition):"
        cat <<NIX
    my.disko.dualBoot = {
      enable = true;
      mode = "useExisting";
      disk = "$disk";

      nixosPartition = "''${disk}''${psuf}N";  # <-- CHANGE 'N' to correct partition number
      # espPartition = "''${esp_part}";

      detection = {
        windowsPartition = "$win_part";
        windowsSize = "$win_size";
        windowsLabel = "''${win_label}";
        espPartition = "''${esp_part}";
        disk = "$disk";
        freeSpace = "$(numfmt --to=iec-i "$used_bytes" 2>/dev/null || echo unknown)";
      };
    };
NIX
        echo
      fi
    done

    if ! "$found_any"; then
      yellow "No Windows installations detected."
      echo "Make sure Windows is installed and disks are connected."
      exit 1
    fi

    echo
    bold "Next steps after detection:"
    echo "  1. Shrink Windows partition to free space:"
    echo "     ntfsresize --force /dev/WIN_PART --size 200G"
    echo "  2. Create NixOS partition in free space:"
    echo "     sgdisk -n 0:0:+100G /dev/DISK"
    echo "  3. Format: mkfs.ext4 /dev/NIXOS_PART"
    echo "  4. Mount:  mount /dev/NIXOS_PART /mnt"
    echo "  5. Generate hardware config: nixos-generate-config --root /mnt"
    echo "  6. Install: nixos-install --flake .#YOUR_HOST"
  '';
}
