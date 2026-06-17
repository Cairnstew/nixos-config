{ writeShellApplication, hyprland, coreutils, gnugrep, gnused, procps, ... }:

writeShellApplication {
  name = "hyprland-status";

  meta = {
    description = "Comprehensive Hyprland compositor status and diagnostics";
    longDescription = ''
      Runs all Hyprland diagnostic commands and presents a clean, unified status
      report. Useful after config changes, during troubleshooting, or for CI checks.

      Usage:
        hyprland-status                      # Full status report
        hyprland-status --quick              # Quick check (config + errors only)
        hyprland-status --monitors           # Monitor info only
        hyprland-status --config             # Show generated config summary
        hyprland-status --version            # Show version info only
        hyprland-status --follow             # Follow hyprctl rollinglog
        hyprland-status --help               # Show this help

      Exit codes:
        0 = all checks passed
        1 = config errors or missing binaries
        2 = Hyprland not running
    '';
    homepage = "https://wiki.hyprland.org/";
    license = "MIT";
    mainProgram = "hyprland-status";
  };

  runtimeInputs = [ hyprland coreutils gnugrep gnused procps ];

  text = ''
    set -euo pipefail

    HCTL="${hyprland}/bin/hyprctl"
    HAS_HYPRCTL=false
    HAS_SESSION=false
    EXIT_CODE=0

    [ -x "$HCTL" ] && HAS_HYPRCTL=true

    # Detect Hyprland session
    if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ -S "/tmp/hypr/''${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket.sock" ] 2>/dev/null; then
      HAS_SESSION=true
    else
      for dir in /run/user/*/hypr/*/; do
        if [ -S "$dir/.socket.sock" ] 2>/dev/null; then
          HAS_SESSION=true
          break
        fi
      done
    fi

    # ── Parsing ──────────────────────────────────────────────────────────
    MODE="full"
    while [ $# -gt 0 ]; do
      case "$1" in
        --quick)    MODE="quick"; shift ;;
        --monitors) MODE="monitors"; shift ;;
        --config)   MODE="config"; shift ;;
        --version)  MODE="version"; shift ;;
        --follow)   MODE="follow"; shift ;;
        --help)
          echo "Usage: hyprland-status [OPTION]"
          echo ""
          echo "  --quick       Quick check (config + errors only)"
          echo "  --monitors    Monitor info only"
          echo "  --config      Show generated config file summary"
          echo "  --version     Show Hyprland version info"
          echo "  --follow      Follow hyprctl rollinglog"
          echo "  --help        Show this help"
          exit 0
          ;;
        *) echo "Unknown option: $1"; exit 1 ;;
      esac
    done

    # ══════════════════════════════════════════════════════════════════════
    # VERSION
    # ══════════════════════════════════════════════════════════════════════
    section_version() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Hyprland Version                                          ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_HYPRCTL && $HAS_SESSION; then
        $HCTL systeminfo 2>/dev/null | head -n 5 || echo "  (unavailable)"
      else
        echo "  Package: ${hyprland}"
        echo "  Version: ${hyprland.version or "unknown"}"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # CONFIG FILE
    # ══════════════════════════════════════════════════════════════════════
    section_config() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Config File                                               ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      HYPR_CONF="/etc/xdg/hypr/hyprland.conf"
      if [ -f "$HYPR_CONF" ]; then
        STORE_PATH=$(readlink -f "$HYPR_CONF" 2>/dev/null || echo "$HYPR_CONF")
        SIZE=$(stat -c%s "$HYPR_CONF" 2>/dev/null || echo 0)
        LINES=$(wc -l < "$HYPR_CONF" 2>/dev/null || echo 0)
        echo "  Path:   $STORE_PATH"
        echo "  Size:   $SIZE bytes, $LINES lines"
        echo "  Key sections:"
        grep -E "^# ──" "$HYPR_CONF" 2>/dev/null | sed 's/^# ──/    ──/' | sed 's/ ──$//' || echo "    (no section markers)"
      else
        echo "  NOT FOUND: $HYPR_CONF"
        EXIT_CODE=1
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # CONFIG ERRORS
    # ══════════════════════════════════════════════════════════════════════
    section_errors() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Config Errors                                             ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_HYPRCTL && $HAS_SESSION; then
        ERRORS=$($HCTL configerrors 2>/dev/null || true)
        if [ -z "$ERRORS" ]; then
          echo "  ✓ No config errors"
        else
          echo "  ✗ Config errors found:"
          echo "  $ERRORS" | sed 's/^/    /'
          EXIT_CODE=1
        fi
      else
        echo "  (requires a running Hyprland session)"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # MONITORS
    # ══════════════════════════════════════════════════════════════════════
    section_monitors() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Monitors                                                  ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_HYPRCTL && $HAS_SESSION; then
        $HCTL monitors 2>/dev/null | grep -E "^Monitor|^  [a-z]" | while IFS= read -r line; do
          echo "  $line"
        done
        MON_COUNT=$($HCTL monitors 2>/dev/null | grep -c "^Monitor" || true)
        echo "  Total: $MON_COUNT monitor(s)"
      else
        echo "  (requires a running Hyprland session)"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # WINDOWS & CLIENTS
    # ══════════════════════════════════════════════════════════════════════
    section_clients() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Windows                                                   ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_HYPRCTL && $HAS_SESSION; then
        CLIENT_COUNT=$($HCTL clients 2>/dev/null | grep -c "Window " || true)
        echo "  Active clients: $CLIENT_COUNT"

        ACTIVE=$($HCTL activewindow 2>/dev/null | grep -E "^Window|class:|title:" | head -3 || true)
        if [ -n "$ACTIVE" ]; then
          echo "  Active window:"
          echo "  $ACTIVE" | sed 's/^/    /'
        fi

        WORKSPACE=$($HCTL activeworkspace 2>/dev/null | head -3 || true)
        if [ -n "$WORKSPACE" ]; then
          echo "  Active workspace:"
          echo "  $WORKSPACE" | sed 's/^/    /'
        fi
      else
        echo "  (requires a running Hyprland session)"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # KEYBINDS
    # ══════════════════════════════════════════════════════════════════════
    section_binds() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Keybinds                                                  ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_HYPRCTL && $HAS_SESSION; then
        BIND_COUNT=$($HCTL binds 2>/dev/null | grep -c "^bind " || true)
        echo "  Total: $BIND_COUNT keybinds"
        $HCTL binds 2>/dev/null | grep "^bind " | head -20 | while IFS= read -r line; do
          echo "  $line"
        done
        TOTAL_BINDS=$($HCTL binds 2>/dev/null | grep -c "^bind " || true)
        if [ "$TOTAL_BINDS" -gt 20 ]; then
          echo "  ... and $((TOTAL_BINDS - 20)) more"
        fi
      else
        echo "  (requires a running Hyprland session)"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # WALLPAPER
    # ══════════════════════════════════════════════════════════════════════
    section_wallpaper() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Wallpaper                                                 ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_SESSION; then
        # Check for wallpaper daemon processes
        for daemon in swaybg hyprpaper awww-daemon mpvpaper; do
          PID=$(pgrep -x "$daemon" 2>/dev/null || true)
          if [ -n "$PID" ]; then
            echo "  $daemon: running (PID $PID)"
          fi
        done

        # hyprpaper specific
        if pgrep -x hyprpaper >/dev/null 2>&1 && $HAS_HYPRCTL; then
          echo "  hyprpaper loaded:"
          $HCTL hyprpaper listloaded 2>/dev/null | sed 's/^/    /' || echo "    (query failed)"
        fi
      else
        # Check config
        echo "  (no session — check config for wallpaper settings)"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # WINDOW RULES
    # ══════════════════════════════════════════════════════════════════════
    section_rules() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Window Rules                                              ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_HYPRCTL && $HAS_SESSION; then
        RULE_COUNT=$($HCTL getoption windowrule 2>/dev/null | grep -c "windowrule" || true)
        echo "  Configured: $RULE_COUNT"
        $HCTL getoption windowrule 2>/dev/null | head -30 | sed 's/^/  /' || true
      else
        echo "  (requires a running Hyprland session)"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # DEVICES
    # ══════════════════════════════════════════════════════════════════════
    section_devices() {
      echo "╔══════════════════════════════════════════════════════════════╗"
      echo "║  Input Devices                                             ║"
      echo "╚══════════════════════════════════════════════════════════════╝"
      if $HAS_HYPRCTL && $HAS_SESSION; then
        $HCTL devices 2>/dev/null | grep -E "^  (keyboard|mouse|touch)" | head -10 | sed 's/^/  /'
        echo "  (use 'hyprctl devices' for full list)"
      else
        echo "  (requires a running Hyprland session)"
      fi
      echo ""
    }

    # ══════════════════════════════════════════════════════════════════════
    # MAIN
    # ══════════════════════════════════════════════════════════════════════
    case "$MODE" in
      quick)
        section_version
        section_config
        section_errors
        section_clients
        ;;
      monitors)
        section_monitors
        ;;
      config)
        section_config
        ;;
      version)
        section_version
        ;;
      follow)
        if $HAS_HYPRCTL && $HAS_SESSION; then
          $HCTL rollinglog -f
        else
          echo "Error: --follow requires a running Hyprland session"
          exit 2
        fi
        ;;
      full)
        section_version
        section_config
        section_errors
        section_monitors
        section_clients
        section_binds
        section_wallpaper
        section_rules
        section_devices
        ;;
    esac

    if [ "$EXIT_CODE" -ne 0 ]; then
      echo "Status: ISSUES DETECTED"
    else
      echo "Status: OK"
    fi
    exit $EXIT_CODE
  '';
}
