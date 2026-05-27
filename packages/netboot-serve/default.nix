{ writeShellApplication, dnsmasq, nginx, ipxe, iproute2, procps, curl, coreutils, gawk, gnused, gnugrep, openssh, ... }:

writeShellApplication {
  name = "netboot-serve";
  meta = {
    description = "Interactive PXE netboot server — DHCP, TFTP, HTTP for provisioning";
    mainProgram = "netboot-serve";
  };
  runtimeInputs = [ dnsmasq nginx ipxe iproute2 procps curl coreutils gawk gnused gnugrep openssh ];

  text = ''
    set -euo pipefail

    # ═══════════════════════════════════════════════════════════════════════════
    #  Defaults
    # ═══════════════════════════════════════════════════════════════════════════
    INTERFACE="eth0"
    SERVER_ADDRESS="192.168.100.1"
    SUBNET_PREFIX="24"
    DHCP_RANGE="192.168.100.100,192.168.100.150"
    DHCP_LEASE="12h"
    TFTP_ROOT="/srv/tftp"
    HTTP_ROOT="/srv/pxe"
    VERBOSE=false

    # ═══════════════════════════════════════════════════════════════════════════
    #  Parse arguments
    # ═══════════════════════════════════════════════════════════════════════════
    usage() {
      cat <<EOF
    Usage: netboot-serve [options]

    Start an interactive PXE netboot server.  Sets up networking, DHCP/TFTP
    (dnsmasq), HTTP (nginx), and a stage-advance webhook.  Press Ctrl+C to
    stop and clean up.

    Options:
      -i, --interface IFACE        Network interface  [$INTERFACE]
      -a, --address IP             Server IP address  [$SERVER_ADDRESS]
      -p, --prefix LEN             Subnet prefix      [$SUBNET_PREFIX]
      -d, --dhcp-range RANGE       DHCP range         [$DHCP_RANGE]
      -l, --dhcp-lease TIME        Lease duration     [$DHCP_LEASE]
      -t, --tftp-root PATH         TFTP root          [$TFTP_ROOT]
      -h, --http-root PATH         HTTP root          [$HTTP_ROOT]
      -v, --verbose                Verbose output
      --help                       Show this help
    EOF
      exit 0
    }

    while [ $# -gt 0 ]; do
      case "$1" in
        -i|--interface)    INTERFACE="$2";  shift 2 ;;
        -a|--address)      SERVER_ADDRESS="$2"; shift 2 ;;
        -p|--prefix)       SUBNET_PREFIX="$2"; shift 2 ;;
        -d|--dhcp-range)   DHCP_RANGE="$2";  shift 2 ;;
        -l|--dhcp-lease)   DHCP_LEASE="$2";  shift 2 ;;
        -t|--tftp-root)    TFTP_ROOT="$2";   shift 2 ;;
        -h|--http-root)    HTTP_ROOT="$2";   shift 2 ;;
        -v|--verbose)      VERBOSE=true;     shift ;;
        --help)            usage ;;
        *) echo "Unknown option: $1"; usage ;;
      esac
    done

    # ═══════════════════════════════════════════════════════════════════════════
    #  Sanity checks
    # ═══════════════════════════════════════════════════════════════════════════
    if [ "$EUID" -ne 0 ]; then
      echo "ERROR: netboot-serve must be run as root (needs to set IP, start services)." >&2
      exit 1
    fi

    if ! ip link show "$INTERFACE" &>/dev/null; then
      echo "ERROR: Interface $INTERFACE not found." >&2
      exit 1
    fi

    # Track PIDs for cleanup
    DNSMASQ_PID=""
    NGINX_PID=""
    TEMP_DIR="$(mktemp -d)"
    CLEANUP_DONE=false

    # ═══════════════════════════════════════════════════════════════════════════
    #  Cleanup handler
    # ═══════════════════════════════════════════════════════════════════════════
    cleanup() {
      $CLEANUP_DONE && return
      CLEANUP_DONE=true
      echo ""
      echo "═══ Stopping netboot server... ═══"

      [ -n "$NGINX_PID" ] && kill "$NGINX_PID" 2>/dev/null && echo "  [✓] HTTP server stopped"
      [ -n "$DNSMASQ_PID" ] && kill "$DNSMASQ_PID" 2>/dev/null && echo "  [✓] DHCP/TFTP stopped"

      # Remove static IP
      ip addr del "$SERVER_ADDRESS/$SUBNET_PREFIX" dev "$INTERFACE" 2>/dev/null || true

      rm -rf "$TEMP_DIR"
      echo "═══ Done ═══"
    }
    trap cleanup EXIT INT TERM

    # ═══════════════════════════════════════════════════════════════════════════
    #  Step 1: Network
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║              Netboot Server                              ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    echo "── Step 1/4: Network ──"
    echo "  Interface: $INTERFACE"
    echo "  Address:   $SERVER_ADDRESS/$SUBNET_PREFIX"

    ip addr add "$SERVER_ADDRESS/$SUBNET_PREFIX" dev "$INTERFACE" 2>/dev/null && \
      echo "  [✓] Static IP set" || \
      echo "  [*] IP already configured (OK)"

    ip link set "$INTERFACE" up

    # ═══════════════════════════════════════════════════════════════════════════
    #  Step 2: TFTP — iPXE binaries
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    echo "── Step 2/4: TFTP — iPXE Binaries ──"
    mkdir -p "$TFTP_ROOT"
    cp -f "${ipxe}/share/ipxe/undionly.kpxe" "$TFTP_ROOT/" 2>/dev/null && echo "  [✓] undionly.kpxe" || echo "  [!] undionly.kpxe not found"
    cp -f "${ipxe}/share/ipxe/ipxe.efi" "$TFTP_ROOT/" 2>/dev/null && echo "  [✓] ipxe.efi" || echo "  [!] ipxe.efi not found"

    # ═══════════════════════════════════════════════════════════════════════════
    #  Step 3: HTTP — nginx
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    echo "── Step 3/4: HTTP — nginx ──"

    mkdir -p "$HTTP_ROOT"

    NGINX_CONF="$TEMP_DIR/nginx.conf"
    cat > "$NGINX_CONF" <<'NGINXEOF'
    events {}
    http {
      server {
        listen __ADDRESS__:80;
        root __HTTP_ROOT__;
        autoindex on;
        sendfile on;
        tcp_nopush on;
      }
    }
    NGINXEOF
    sed -i "s|__ADDRESS__|$SERVER_ADDRESS|g; s|__HTTP_ROOT__|$HTTP_ROOT|g" "$NGINX_CONF"

    nginx -c "$NGINX_CONF" -p "$TEMP_DIR" 2>&1 || true
    NGINX_PID=$(cat "$TEMP_DIR/logs/nginx.pid" 2>/dev/null || echo "")
    if [ -n "$NGINX_PID" ] && kill -0 "$NGINX_PID" 2>/dev/null; then
      echo "  [✓] HTTP server running (PID $NGINX_PID)"
    else
      # Try again without pid file
      nginx -c "$NGINX_CONF" -p "$TEMP_DIR" 2>/dev/null && \
        echo "  [✓] HTTP server started" || \
        echo "  [!] HTTP server may have failed — check logs"
    fi

    # ═══════════════════════════════════════════════════════════════════════════
    #  Step 4: DHCP + TFTP — dnsmasq
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    echo "── Step 4/4: DHCP + TFTP — dnsmasq ──"

    DNSMASQ_CONF="$TEMP_DIR/dnsmasq.conf"
    cat > "$DNSMASQ_CONF" <<'DNSMASQEOF'
    interface=__INTERFACE__
    bind-interfaces
    dhcp-range=__DHCP_RANGE__,__DHCP_LEASE__
    enable-tftp
    tftp-root=__TFTP_ROOT__
    dhcp-boot=undionly.kpxe
    dhcp-match=set:efi-x86_64,option:client-arch,7
    dhcp-boot=tag:efi-x86_64,ipxe.efi
    dhcp-match=set:ipxe,175
    dhcp-boot=tag:ipxe,http://__ADDRESS__/boot.ipxe
    DNSMASQEOF
    sed -i "s|__INTERFACE__|$INTERFACE|g; s|__DHCP_RANGE__|$DHCP_RANGE|g; s|__DHCP_LEASE__|$DHCP_LEASE|g; s|__TFTP_ROOT__|$TFTP_ROOT|g; s|__ADDRESS__|$SERVER_ADDRESS|g" "$DNSMASQ_CONF"

    dnsmasq -C "$DNSMASQ_CONF" --no-daemon &
    DNSMASQ_PID=$!
    sleep 1
    if kill -0 "$DNSMASQ_PID" 2>/dev/null; then
      echo "  [✓] DHCP/TFTP running (PID $DNSMASQ_PID)"
    else
      echo "  [!] dnsmasq failed to start"
    fi

    # Webhook not needed in CLI mode — use the interactive prompt to advance stages.

    # ═══════════════════════════════════════════════════════════════════════════
    #  Summary
    # ═══════════════════════════════════════════════════════════════════════════
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  Netboot server is running                               ║"
    echo "║                                                          ║"
    echo "║  DHCP+TFTP:  $SERVER_ADDRESS:67/69    (dnsmasq)  ║"
    echo "║  HTTP:        $SERVER_ADDRESS:80         (nginx)    ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    # Scan for machines
    echo "Configured machines:"
    if [ -d "$HTTP_ROOT/stages" ]; then
      for mac_dir in "$HTTP_ROOT/stages"/*/; do
        [ -d "$mac_dir" ] || continue
        mac="$(basename "$mac_dir")"
        target="$(readlink "$HTTP_ROOT/$mac.ipxe" 2>/dev/null || echo "NOT INIT")"
        echo "  $mac → $target"
      done
    else
      echo "  (no machines configured — place stage scripts in $HTTP_ROOT/stages/)"
    fi
    echo ""

    echo "Commands:  advance <mac> | list | quit"
    echo "─────────────────────────────────────────────"

    # ═══════════════════════════════════════════════════════════════════════════
    #  Interactive loop
    # ═══════════════════════════════════════════════════════════════════════════
    while true; do
      read -r -p "netboot> " cmd args || { echo ""; break; }
      case "$cmd" in
        advance)
          if [ -z "$args" ]; then
            echo "Usage: advance <mac>"
            continue
          fi
          mac="$args"
          if [ ! -f "$HTTP_ROOT/stages/$mac/stage-windows.ipxe" ] && \
             [ ! -f "$HTTP_ROOT/stages/$mac/stage-nixos.ipxe" ] && \
             [ ! -f "$HTTP_ROOT/stages/$mac/stage-done.ipxe" ]; then
            echo "ERROR: No stage scripts found for $mac"
            continue
          fi
          current="$(readlink "$HTTP_ROOT/$mac.ipxe" 2>/dev/null || echo "")"
          if [ -z "$current" ]; then
            # Init: set to first available stage
            for s in discover windows nixos done; do
              if [ -f "$HTTP_ROOT/stages/$mac/stage-$s.ipxe" ]; then
                ln -sf "stages/$mac/stage-$s.ipxe" "$HTTP_ROOT/$mac.ipxe"
                echo "  $mac initialized → $s"
                break
              fi
            done
            continue
          fi
          cur_stage="$(basename "$current" .ipxe | sed 's/^stage-//')"
          next=""
          found=0
          for s in discover windows nixos done; do
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
        list|status)
          echo "Machines:"
          for mac_dir in "$HTTP_ROOT/stages"/*/; do
            [ -d "$mac_dir" ] || continue
            mac="$(basename "$mac_dir")"
            target="$(readlink "$HTTP_ROOT/$mac.ipxe" 2>/dev/null || echo "NOT INIT")"
            echo "  $mac → $target"
          done
          ;;
        quit|exit)
          echo "Stopping..."
          break
          ;;
        help)
          echo "Commands:  advance <mac> | list | quit"
          ;;
        *)
          echo "Unknown: $cmd  (try: advance <mac> | list | quit)"
          ;;
      esac
    done
  '';
}
