{ writeShellApplication, dnsmasq, nginx, ipxe, iproute2, procps, curl, coreutils, gawk, gnused, gnugrep, openssh, ethtool, jq, ... }:

writeShellApplication {
  name = "netboot-serve";
  meta = {
    description = "Interactive PXE netboot server — profile selection wizard with auto-detection";
    mainProgram = "netboot-serve";
  };
  runtimeInputs = [ dnsmasq nginx ipxe iproute2 procps curl coreutils gawk gnused gnugrep openssh ethtool jq ];

  text = ''
    set -euo pipefail

    INTERFACE=""
    SERVER_ADDRESS=""
    SUBNET_PREFIX="24"
    DHCP_RANGE=""
    DHCP_LEASE="24h"
    TFTP_ROOT="/srv/tftp"
    HTTP_ROOT="/srv/pxe"
    PROFILE_NAME=""
    TARGET_MAC=""

    usage() {
      cat <<EOF
    Usage: netboot-serve [options]

    Interactive PXE netboot server. Starts a DHCP + TFTP + HTTP server for
    provisioning machines over the network.

    Options:
      -p, --profile NAME        Skip profile selection
      -m, --mac ADDRESS         Target MAC address
      -i, --interface IFACE     Network interface (auto-detected if omitted)
      -a, --address IP          Server IP (auto-suggested if omitted)
      -n, --prefix LEN          Subnet prefix      [$SUBNET_PREFIX]
      -d, --dhcp-range RANGE    DHCP range         (auto-derived if omitted)
      -l, --dhcp-lease TIME     Lease duration     [$DHCP_LEASE]
      -t, --tftp-root PATH      TFTP root          [$TFTP_ROOT]
      -h, --http-root PATH      HTTP root          [$HTTP_ROOT]
      --help                    Show this help
    EOF
      exit 0
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        -p|--profile)        PROFILE_NAME="$2";   shift 2 ;;
        -m|--mac)            TARGET_MAC="$2";     shift 2 ;;
        -i|--interface)      INTERFACE="$2";      shift 2 ;;
        -a|--address)        SERVER_ADDRESS="$2"; shift 2 ;;
        -n|--prefix)         SUBNET_PREFIX="$2";  shift 2 ;;
        -d|--dhcp-range)     DHCP_RANGE="$2";     shift 2 ;;
        -l|--dhcp-lease)     DHCP_LEASE="$2";     shift 2 ;;
        -t|--tftp-root)      TFTP_ROOT="$2";      shift 2 ;;
        -h|--http-root)      HTTP_ROOT="$2";      shift 2 ;;
        --help)              usage ;;
        *) echo "Unknown: $1"; usage ;;
      esac
    done

    if [ "$EUID" -ne 0 ]; then
      echo "ERROR: netboot-serve must be run as root." >&2
      exit 1
    fi

    prompt() {
      local var="$1" msg="$2" default="$3"
      local val
      if [ -n "$default" ]; then
        read -r -p "$msg [$default]: " val
        printf -v "$var" '%s' "''${val:-$default}"
      else
        read -r -p "$msg: " val
        printf -v "$var" '%s' "$val"
      fi
    }

    # ═══════════════════════════════════════════════════════════════════════════
    #  Interface auto-detection
    # ═══════════════════════════════════════════════════════════════════════════
    select_interface() {
      echo "── Scanning network interfaces ──"
      local interfaces=()
      local iface ip line

      while read -r line; do
        iface=$(echo "$line" | awk '{print $1}')
        case "$iface" in
          lo|docker*|tailscale*|veth*|br-*) continue ;;
        esac
        state=$(echo "$line" | awk '{print $2}')
        [ "$state" != "UP" ] && continue
        # Prefer IPv4; get all IPs on this interface
        local all_ips=""
        all_ips=$(ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2}' | head -1)
        if [ -z "$all_ips" ]; then
          all_ips=$(ip -br addr show "$iface" 2>/dev/null | awk '{print $3}')
        fi
        interfaces+=("$iface|$all_ips")
      done < <(ip -br addr show 2>/dev/null)

      if [ ''${#interfaces[@]} -eq 0 ]; then
        echo "No suitable network interfaces found."
        exit 1
      fi

      if [ ''${#interfaces[@]} -eq 1 ]; then
        local entry=''${interfaces[0]}
        INTERFACE="''${entry%%|*}"
        local ip_part="''${entry#*|}"
        [ -z "$SERVER_ADDRESS" ] && SERVER_ADDRESS="$ip_part"
        echo "  [✓] Auto-selected: $INTERFACE ($ip_part)"
      else
        echo "  Available interfaces:"
        local i=1
        for entry in "''${interfaces[@]}"; do
          iface="''${entry%%|*}"
          ip="''${entry#*|}"
          echo "    $i) $iface — ''${ip:-no IP}"
          i=$((i + 1))
        done
        prompt NUM "Select interface" "1"
        local idx=$((NUM - 1))
        [ "$idx" -ge 0 ] && [ "$idx" -lt ''${#interfaces[@]} ] || { echo "Invalid"; exit 1; }
        local entry=''${interfaces[$idx]}
        INTERFACE="''${entry%%|*}"
        local ip_part="''${entry#*|}"
        [ -z "$SERVER_ADDRESS" ] && SERVER_ADDRESS="$ip_part"
      fi

      # Strip CIDR; reject IPv6 (fe80:: etc.)
      SERVER_ADDRESS="''${SERVER_ADDRESS%/*}"
      case "$SERVER_ADDRESS" in
        fe80:*|fe90:*|fec0:*|fc*|fd*|*:*)
          echo "  [!] Only IPv6 found on $INTERFACE — using default 192.168.99.1/24"
          SERVER_ADDRESS="192.168.99.1"
          ;;
      esac
      if [ -z "$SERVER_ADDRESS" ]; then
        SERVER_ADDRESS="192.168.99.1"
        echo "  [*] No IP on $INTERFACE — suggest $SERVER_ADDRESS"
      fi
      echo "  Interface: $INTERFACE"
      echo "  Address:   $SERVER_ADDRESS/$SUBNET_PREFIX"
    }

    # ═══════════════════════════════════════════════════════════════════════════
    #  Profile discovery
    # ═══════════════════════════════════════════════════════════════════════════
    discover_profiles() {
      echo ""
      echo "── Discovering boot profiles ──"
      PROFILES=()
      PROFILE_NAMES=()

      if [ -d "$HTTP_ROOT/profiles" ]; then
        for pdir in "$HTTP_ROOT/profiles"/*/; do
          [ -d "$pdir" ] || continue
          local name desc
          name=$(basename "$pdir")
          desc=$(jq -r '.description // "NixOS profile"' "$pdir/profile.json" 2>/dev/null || echo "NixOS profile")
          PROFILE_NAMES+=("$name")
          PROFILES+=("$name|$desc|system|$pdir")
        done
      fi

      local has_nixos=false
      for p in "''${PROFILES[@]}"; do
        [ "''${p%%|*}" = "nixos-minimal" ] && has_nixos=true
      done
      if ! $has_nixos; then
        PROFILE_NAMES+=("nixos-minimal")
        PROFILES+=("nixos-minimal|NixOS Minimal (chainload upstream netboot)|builtin|")
      fi

      PROFILE_NAMES+=("local-boot")
      PROFILES+=("local-boot|Boot from local disk (exit PXE)|builtin|")

      echo "  Available profiles:"
      local i=1
      for entry in "''${PROFILES[@]}"; do
        local desc
        desc=$(echo "$entry" | awk -F'|' '{print $2}')
        echo "    $i) $desc"
        i=$((i + 1))
      done

      if [ -z "$PROFILE_NAME" ]; then
        prompt SEL "Select profile" "1"
        local idx=$((SEL - 1))
        [ "$idx" -ge 0 ] && [ "$idx" -lt ''${#PROFILES[@]} ] || { echo "Invalid"; exit 1; }
        PROFILE_NAME=$(echo "''${PROFILES[$idx]}" | awk -F'|' '{print $1}')
      fi
      echo "  Selected: $PROFILE_NAME"
    }

    # ═══════════════════════════════════════════════════════════════════════════
    #  Target MAC
    # ═══════════════════════════════════════════════════════════════════════════
    get_mac() {
      echo ""
      echo "── Target machine MAC address ──"
      local LEASE_FILE="/var/lib/misc/dnsmasq.leases"

      if [ -z "$TARGET_MAC" ]; then
        if [ -f "$LEASE_FILE" ]; then
          prompt MAC "MAC address (or 'scan')" "scan"
        else
          prompt MAC "MAC address" ""
        fi

        if [ "$MAC" = "scan" ]; then
          echo "  Scanning DHCP leases..."
          local found=false
          while read -r _ mac ip hostname _; do
            [ -n "$mac" ] || continue
            echo "    $mac  $ip  ''${hostname:-(unknown)}"
            found=true
          done < "$LEASE_FILE" 2>/dev/null || true
          if ! $found; then
            echo "    No active leases."
          fi
          prompt TARGET_MAC "Enter MAC from list" ""
        else
          TARGET_MAC="$MAC"
        fi
        [ -z "$TARGET_MAC" ] && { echo "MAC is required."; exit 1; }
      fi
      echo "  Target MAC: $TARGET_MAC"
    }

    # ═══════════════════════════════════════════════════════════════════════════
    #  Network config
    # ═══════════════════════════════════════════════════════════════════════════
    configure_network() {
      echo ""
      echo "── Network configuration ──"
      if [ -z "$SERVER_ADDRESS" ]; then
        SERVER_ADDRESS="192.168.99.1"
      fi
      prompt SERVER_ADDRESS "Server IP" "$SERVER_ADDRESS"
      if [ -z "$DHCP_RANGE" ]; then
        local base
        base=''${SERVER_ADDRESS%.*}
        DHCP_RANGE="$base.100,$base.200"
      fi
      prompt DHCP_RANGE "DHCP range (start,end)" "$DHCP_RANGE"
      echo "  Server: $SERVER_ADDRESS/$SUBNET_PREFIX"
      echo "  DHCP:   $DHCP_RANGE"
    }

    # ═══════════════════════════════════════════════════════════════════════════
    #  PXE directory setup — write stage scripts with { echo ...; } > file
    #  to avoid heredoc delimiter column-0 requirement.
    # ═══════════════════════════════════════════════════════════════════════════
    setup_pxe() {
      local profile_entry ptype pdir mac stages_dir machines_dir

      echo ""
      echo "═══ Setting up PXE for $TARGET_MAC ($PROFILE_NAME) ═══"

      for entry in "''${PROFILES[@]}"; do
        local pname
        pname=$(echo "$entry" | awk -F'|' '{print $1}')
        if [ "$pname" = "$PROFILE_NAME" ]; then
          profile_entry="$entry"
          break
        fi
      done
      if [ -z "$profile_entry" ]; then
        echo "ERROR: Profile $PROFILE_NAME not found"; exit 1
      fi

      ptype=$(echo "$profile_entry" | awk -F'|' '{print $3}')
      pdir=$(echo "$profile_entry" | awk -F'|' '{print $4}')
      mac="$TARGET_MAC"

      # Ensure writable stages/machines dirs (tmpfiles may have created Nix-store symlinks)
      if [ -L "$HTTP_ROOT/stages" ]; then
        echo "  [*] Replacing read-only stages symlink with writable directory"
        rm -f "$HTTP_ROOT/stages"
        mkdir -p "$HTTP_ROOT/stages"
      fi
      if [ -L "$HTTP_ROOT/machines" ]; then
        echo "  [*] Replacing read-only machines symlink with writable directory"
        rm -f "$HTTP_ROOT/machines"
        mkdir -p "$HTTP_ROOT/machines"
      fi
      if [ -L "$HTTP_ROOT/boot.ipxe" ]; then
        rm -f "$HTTP_ROOT/boot.ipxe"
      fi

      stages_dir="$HTTP_ROOT/stages/$mac"
      machines_dir="$HTTP_ROOT/machines/$mac"
      mkdir -p "$stages_dir" "$machines_dir"

      # Determine stages
      local stages_json
      stages_json=""

      if [ "$ptype" = "system" ] && [ -n "$pdir" ] && [ -f "$pdir/profile.json" ]; then
        stages_json=$(jq -c '.stages' "$pdir/profile.json" 2>/dev/null || echo '[]')
      else
        case "$PROFILE_NAME" in
          nixos-minimal) stages_json='["nixos","done"]' ;;
          local-boot)    stages_json='["done"]' ;;
          *)             stages_json='["windows","nixos","done"]' ;;
        esac
      fi

      local stages=()
      while IFS= read -r s; do
        s=$(echo "$s" | tr -d ' "')
        [ -n "$s" ] && stages+=("$s")
      done < <(echo "$stages_json" | jq -r '.[]' 2>/dev/null || echo "")
      [ ''${#stages[@]} -eq 0 ] && stages=("done")

      # Link artifacts from profile dir
      if [ "$ptype" = "system" ] && [ -n "$pdir" ]; then
        for art in autounattend.xml apply-dsc.ps1 vmlinuz initrd config.tar.gz; do
          if [ -f "$pdir/$art" ]; then
            cp -L "$pdir/$art" "$machines_dir/$art" 2>/dev/null && echo "  [✓] $art linked"
          fi
        done
      fi

      local win_has_unattend=false
      [ -f "$machines_dir/autounattend.xml" ] && win_has_unattend=true

      # Generate stage scripts using { echo; } > file to avoid heredoc issues
      for stage in "''${stages[@]}"; do
        local sf="$stages_dir/stage-$stage.ipxe"
        case "$stage" in
          discover)
            if [ -f "$machines_dir/vmlinuz" ] && [ -f "$machines_dir/initrd" ]; then
              { echo '#!ipxe'
                echo "echo \"=== Stage: Discover ($PROFILE_NAME) ===\""
                echo "echo \"Booting interactive disk/hostname selector...\""
                echo "kernel http://$SERVER_ADDRESS/machines/$mac/vmlinuz pxe.server=$SERVER_ADDRESS pxe.mac=$mac pxe.stage=discover console=tty0 console=ttyS0,115200n8 ip=dhcp"
                echo "initrd http://$SERVER_ADDRESS/machines/$mac/initrd"
                echo "boot"
              } > "$sf"
            else
              { echo '#!ipxe'
                echo "echo \"Discover stage unavailable — missing vmlinuz/initrd\""
                echo "shell"
              } > "$sf"
            fi
            ;;
          windows)
            if [ -d "$HTTP_ROOT/windows" ] && [ -f "$HTTP_ROOT/windows/sources/boot.wim" ]; then
              { echo '#!ipxe'
                echo "echo \"=== Stage: Windows Installer ($PROFILE_NAME) ===\""
                echo "kernel wimboot"
                if $win_has_unattend; then
                  echo "initrd http://$SERVER_ADDRESS/machines/$mac/autounattend.xml  autounattend.xml"
                fi
                echo "initrd http://$SERVER_ADDRESS/windows/boot/bcd         BCD"
                echo "initrd http://$SERVER_ADDRESS/windows/boot/boot.sdi    boot.sdi"
                echo "initrd http://$SERVER_ADDRESS/windows/sources/boot.wim boot.wim"
                echo "boot"
              } > "$sf"
            else
              { echo '#!ipxe'
                echo "echo \"=== Stage: Windows Installer ($PROFILE_NAME) ===\""
                echo "echo \"Windows boot files not found at $HTTP_ROOT/windows\""
                echo "echo \"Enable my.services.windowsIsoSync or place boot files manually.\""
                echo "shell"
              } > "$sf"
            fi
            ;;
          nixos)
            if [ -f "$machines_dir/vmlinuz" ] && [ -f "$machines_dir/initrd" ]; then
              { echo '#!ipxe'
                echo "echo \"=== Stage: NixOS Installer ($PROFILE_NAME) ===\""
                echo "echo \"Booting custom netboot installer...\""
                echo "kernel http://$SERVER_ADDRESS/machines/$mac/vmlinuz pxe.server=$SERVER_ADDRESS pxe.mac=$mac console=tty0 console=ttyS0,115200n8 ip=dhcp"
                echo "initrd http://$SERVER_ADDRESS/machines/$mac/initrd"
                echo "boot"
              } > "$sf"
            else
              { echo '#!ipxe'
                echo "echo \"=== Stage: NixOS Installer ($PROFILE_NAME) ===\""
                echo "echo \"Chainloading upstream NixOS netboot...\""
                echo "chain https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/netboot-x86_64-linux.ipxe || echo \"Failed\""
                echo "shell"
              } > "$sf"
            fi
            ;;
          done)
            { echo '#!ipxe'
              echo "echo \"=== Stage: Done ($PROFILE_NAME) ===\""
              echo "echo \"Installation complete — booting from local disk\""
              echo "exit"
            } > "$sf"
            ;;
        esac
        echo "  [✓] Stage $stage created"
      done

      # MAC symlink to first stage
      local first_stage="''${stages[0]}"
      ln -sf "stages/$mac/stage-$first_stage.ipxe" "$HTTP_ROOT/$mac.ipxe"
      echo "  [✓] $mac → stage $first_stage"

      # boot.ipxe
      # Always regenerate boot.ipxe (may have stale server address from a prior run)
      { echo '#!ipxe'
        echo "echo \"=== NixOS Netboot Server ===\""
        echo ":$mac"
        echo "chain http://$SERVER_ADDRESS/$mac.ipxe || goto next"
        echo ":next"
        echo "echo \"No matching machine config — booting local disk\""
        echo "exit"
      } > "$HTTP_ROOT/boot.ipxe"
      echo "  [✓] boot.ipxe updated with $SERVER_ADDRESS"

      # autoexec.ipxe — iPXE loads this from TFTP after boot, chains to HTTP
      { echo '#!ipxe'
        echo "echo \"=== NixOS PXE Server — loading boot.ipxe ===\""
        echo "chain http://$SERVER_ADDRESS/boot.ipxe || shell"
      } > "$TFTP_ROOT/autoexec.ipxe"
      echo "  [✓] autoexec.ipxe created"
    }

    # ═══════════════════════════════════════════════════════════════════════════
    #  Main
    # ═══════════════════════════════════════════════════════════════════════════
    main() {
      echo ""
      echo "╔═══════════════════════════════════════════════════════════╗"
      echo "║              Netboot Server Wizard                        ║"
      echo "╚═══════════════════════════════════════════════════════════╝"
      echo ""

      if [ -z "$INTERFACE" ]; then
        select_interface
      else
        if ! ip link show "$INTERFACE" &>/dev/null; then
          echo "ERROR: Interface $INTERFACE not found." >&2
          exit 1
        fi
        echo "  Interface: $INTERFACE (specified)"
        if [ -z "$SERVER_ADDRESS" ]; then
          local current_ip
          current_ip=$(ip -br addr show "$INTERFACE" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)
          [ -n "$current_ip" ] && SERVER_ADDRESS="$current_ip" && echo "  Address: $SERVER_ADDRESS (from interface)"
        fi
      fi

      discover_profiles
      get_mac
      configure_network
      setup_pxe
    }

    DNSMASQ_PID=""
    NGINX_PID=""
    TEMP_DIR="$(mktemp -d)"
    CLEANUP_DONE=false

    cleanup() {
      $CLEANUP_DONE && return
      CLEANUP_DONE=true
      echo ""
      echo "═══ Stopping netboot server... ═══"
      if [ -z "$NGINX_PID" ] && [ -f "$TEMP_DIR/nginx.pid" ]; then
        NGINX_PID=$(cat "$TEMP_DIR/nginx.pid" 2>/dev/null || echo "")
      fi
      [ -n "$NGINX_PID" ] && kill "$NGINX_PID" 2>/dev/null && echo "  [✓] HTTP server stopped"
      [ -n "$DNSMASQ_PID" ] && kill "$DNSMASQ_PID" 2>/dev/null && echo "  [✓] DHCP/TFTP stopped"
      ip addr del "$SERVER_ADDRESS/$SUBNET_PREFIX" dev "$INTERFACE" 2>/dev/null || true
      systemctl start dnsmasq 2>/dev/null || true
      rm -rf "$TEMP_DIR"
      echo "═══ Done ═══"
    }
    trap cleanup EXIT INT TERM

    main

    # ── Server startup ──
    echo ""
    echo "── Starting services ──"

    ip addr add "$SERVER_ADDRESS/$SUBNET_PREFIX" dev "$INTERFACE" 2>/dev/null && \
      echo "  [✓] Static IP set" || echo "  [*] IP already configured (OK)"
    ip link set "$INTERFACE" up

    echo ""
    echo "── TFTP — iPXE Binaries ──"
    mkdir -p "$TFTP_ROOT"
    rm -f "$TFTP_ROOT/undionly.kpxe" "$TFTP_ROOT/ipxe.efi"
    cp -f "${ipxe}/undionly.kpxe" "$TFTP_ROOT/" && echo "  [✓] undionly.kpxe" || echo "  [!] undionly.kpxe not found"
    cp -f "${ipxe}/ipxe.efi" "$TFTP_ROOT/" && echo "  [✓] ipxe.efi" || echo "  [!] ipxe.efi not found"
    # autoexec.ipxe is created during setup_pxe; ensure it exists as fallback
    if [ ! -f "$TFTP_ROOT/autoexec.ipxe" ]; then
      { echo '#!ipxe'; echo "chain http://$SERVER_ADDRESS/boot.ipxe || shell"; } > "$TFTP_ROOT/autoexec.ipxe" 2>/dev/null && echo "  [✓] autoexec.ipxe (fallback)"
    fi

    echo ""
    echo "── HTTP — nginx ──"
    mkdir -p "$HTTP_ROOT"
    # nginx needs the log dir to exist; the -p prefix only affects relative paths
    mkdir -p "$TEMP_DIR/logs"
    NGINX_CONF="$TEMP_DIR/nginx.conf"
    cat > "$NGINX_CONF" <<NGINXEOF
    error_log $TEMP_DIR/nginx-error.log;
    events {}
    http {
      log_format netboot '\$remote_addr - \$remote_user [\$time_local] '
                          '"\$request" \$status \$body_bytes_sent '
                          '"\$http_referer" "\$http_user_agent"';
      access_log $TEMP_DIR/nginx-access.log netboot;
      server {
        listen $SERVER_ADDRESS:80;
        root $HTTP_ROOT;
        autoindex on;
        sendfile on;
        tcp_nopush on;
      }
    }
    NGINXEOF

    # nginx -p prefix doesn't override compile-time pid-path/error-log-path.
    # Use -g to set them at runtime so we don't need /var/log/nginx/.
    export NGINX_GLOBALS="pid $TEMP_DIR/nginx.pid; error_log $TEMP_DIR/nginx-error.log;"
    if nginx -c "$NGINX_CONF" -p "$TEMP_DIR" -g "$NGINX_GLOBALS" 2>&1; then
      echo "  [✓] HTTP server started"
    else
      echo "  [!] nginx failed to start"
      cat "$TEMP_DIR/nginx-error.log" 2>/dev/null || true
    fi
    # Capture PID
    sleep 0.3
    NGINX_PID=$(cat "$TEMP_DIR/nginx.pid" 2>/dev/null || echo "")
    if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
      echo "  [✓] HTTP server running (PID $NGINX_PID)"
    else
      echo "  [!] nginx not running after start attempt"
      cat "$TEMP_DIR/nginx-error.log" 2>/dev/null || true
    fi

    echo ""
    echo "── DHCP + TFTP — dnsmasq ──"
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
      echo "  [*] Stopping system dnsmasq (conflicts with PXE DHCP on $INTERFACE)"
      systemctl stop dnsmasq
    fi

    DNSMASQ_CONF="$TEMP_DIR/dnsmasq.conf"
    cat > "$DNSMASQ_CONF" <<DNSMASQEOF
    interface=$INTERFACE
    bind-interfaces
    dhcp-range=$DHCP_RANGE,$DHCP_LEASE
    enable-tftp
    tftp-root=$TFTP_ROOT
    dhcp-boot=undionly.kpxe
    dhcp-match=set:efi-x86_64,option:client-arch,7
    dhcp-boot=tag:efi-x86_64,ipxe.efi
    dhcp-match=set:ipxe,175
    dhcp-boot=tag:ipxe,http://$SERVER_ADDRESS/boot.ipxe
    DNSMASQEOF

    dnsmasq -C "$DNSMASQ_CONF" --no-daemon &
    DNSMASQ_PID=$!
    sleep 1
    if kill -0 "$DNSMASQ_PID" 2>/dev/null; then
      echo "  [✓] DHCP/TFTP running (PID $DNSMASQ_PID)"
    else
      echo "  [!] dnsmasq failed to start"
    fi

    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  Netboot server is running                               ║"
    echo "║                                                          ║"
    echo "║  Profile:    $PROFILE_NAME                      ║"
    echo "║  Target:     $TARGET_MAC                   ║"
    echo "║  DHCP+TFTP:  $SERVER_ADDRESS:67/69    (dnsmasq)  ║"
    echo "║  HTTP:        $SERVER_ADDRESS:80         (nginx)    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "PXE-boot the target machine to start."
    echo "Commands:  advance <mac> | list | help | quit"
    echo "───────────────────────────────────────────────────────────"

    while true; do
      read -r -p "netboot> " cmd args || { echo ""; break; }
      case "$cmd" in
        advance)
          if [ -z "$args" ]; then
            echo "Usage: advance <mac>"
            continue
          fi
          mac="$args"
          current="$(readlink "$HTTP_ROOT/$mac.ipxe" 2>/dev/null || echo "")"
          if [ -z "$current" ]; then
            for s in discover windows nixos "done"; do
              if [ -f "$HTTP_ROOT/stages/$mac/stage-$s.ipxe" ]; then
                ln -sf "stages/$mac/stage-$s.ipxe" "$HTTP_ROOT/$mac.ipxe"
                echo "  $mac initialized → $s"
                break
              fi
            done
            continue
          fi
          cur_stage=$(basename "$current" .ipxe | sed 's/^stage-//')
          next=""
          found=0
          for s in discover windows nixos "done"; do
            [ "$found" = "1" ] && { next="$s"; break; }
            [ "$s" = "$cur_stage" ] && found=1
          done
          if [ -z "$next" ]; then
            echo "  $mac already at final stage ($cur_stage)"
          else
            ln -sf "stages/$mac/stage-$next.ipxe" "$HTTP_ROOT/$mac.ipxe"
            echo "  $mac advanced: $cur_stage → $next"
          fi
          ;;
        list)
          echo "Machines:"
          for mac_dir in "$HTTP_ROOT/stages"/*/; do
            [ -d "$mac_dir" ] || continue
            m=$(basename "$mac_dir")
            tgt=$(readlink "$HTTP_ROOT/$m.ipxe" 2>/dev/null || echo "NOT INIT")
            echo "  $m → $tgt"
          done
          ;;
        quit|exit)
          echo "Stopping..."
          break
          ;;
        help)
          echo "Commands:  advance <mac> | list | help | quit"
          ;;
        *)
          echo "Unknown: $cmd  (try: advance <mac> | list | help | quit)"
          ;;
      esac
    done
  '';
}
