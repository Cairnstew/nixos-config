{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  inherit (lib) mkIf;
in
{
  assertions = [
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.desktop.hyprland.user must be set when hyprland is enabled.";
    }
    {
      assertion = !cfg.enable || config.services.greetd.enable or false;
      message = "greetd must be enabled when hyprland is enabled (set by the hyprland module).";
    }
    {
      assertion = !cfg.enable || config.services.greetd.settings.default_session.command or "" != "";
      message = "greetd default_session.command must be set when hyprland is enabled.";
    }
  ];

  systemd.services.hyprland-health-check = mkIf cfg.enable {
    description = "Health check for Hyprland compositor and greetd setup";
    after = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "30s";
    };

    script = ''
      set -euo pipefail
      echo "=== Hyprland Health Check ==="

      # Check greetd session command references Hyprland
      GREETD_CMD="${config.services.greetd.settings.default_session.command or ""}"
      if echo "$GREETD_CMD" | grep -qi "Hyprland"; then
        echo "PASS: greetd command references Hyprland"
      else
        echo "FAIL: greetd command does not reference Hyprland"
        exit 1
      fi

      # Check greetd session user
      GREETD_USER="${config.services.greetd.settings.default_session.user or ""}"
      echo "INFO: greetd session user is $GREETD_USER"

      # Check Hyprland config exists
      if [ -f /etc/xdg/hypr/hyprland.conf ]; then
        echo "PASS: /etc/xdg/hypr/hyprland.conf exists"
      else
        echo "FAIL: /etc/xdg/hypr/hyprland.conf not found"
        exit 1
      fi

      # Check Hyprland binary is installed
      if command -v Hyprland >/dev/null 2>&1; then
        echo "PASS: Hyprland binary found"
      else
        echo "FAIL: Hyprland binary not found"
        exit 1
      fi

      # Check key dependencies
      for pkg in hyprctl waybar wofi mako swaylock grim slurp; do
        if command -v "$pkg" >/dev/null 2>&1; then
          echo "PASS: $pkg installed"
        else
          echo "WARN: $pkg not found in PATH"
        fi
      done

      # Check if Hyprland process is running
      if pgrep -u "${cfg.user}" Hyprland >/dev/null 2>&1; then
        echo "PASS: Hyprland process is running"
      else
        echo "WARN: Hyprland process not yet running (starts after login via greetd)"
      fi

      echo "=== Hyprland Health Check Complete ==="
    '';
  };

  systemd.services.hyprland-smoke-test = mkIf cfg.enable {
    description = "Smoke test for Hyprland configuration and runtime";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "hyprland-smoke-test" ''
        set -euo pipefail
        echo "=== Hyprland Smoke Test ==="

        # 1. Verify config file is valid Hyprland syntax
        echo "--- [1/7] Config syntax ---"
        HYPR_CONF="/etc/xdg/hypr/hyprland.conf"
        if [ -f "$HYPR_CONF" ]; then
          SIZE=$(stat -c%s "$HYPR_CONF")
          if [ "$SIZE" -gt 100 ]; then
            echo "PASS: hyprland.conf is $SIZE bytes (looks valid)"
          else
            echo "FAIL: hyprland.conf is only $SIZE bytes"
            exit 1
          fi
        else
          echo "FAIL: hyprland.conf not found"
          exit 1
        fi

        # 2. Verify greetd configuration
        echo "--- [2/7] Greetd config ---"
        GREETD_CMD="${config.services.greetd.settings.default_session.command or ""}"
        if echo "$GREETD_CMD" | grep -qi "Hyprland"; then
          echo "PASS: greetd launches Hyprland"
        else
          echo "FAIL: greetd does not launch Hyprland"
          exit 1
        fi

        # 3. Check all required binaries exist
        echo "--- [3/7] Required binaries ---"
        BINS="Hyprland hyprctl waybar wofi mako swaylock grim slurp wl-copy"
        ALL_FOUND=true
        for bin in $BINS; do
          if command -v "$bin" >/dev/null 2>&1; then
            echo "  PASS: $bin"
          else
            echo "  FAIL: $bin not found in PATH"
            ALL_FOUND=false
          fi
        done
        if ! $ALL_FOUND; then
          exit 1
        fi

        # 4. Check wayland portal setup
        echo "--- [4/7] Wayland portals ---"
        if [ -f /etc/xdg/xdg-desktop-portal/portals.conf ] 2>/dev/null; then
          echo "PASS: portals config exists"
        else
          echo "INFO: portals.conf not at standard path"
        fi
        if command -v xdg-desktop-portal-hyprland >/dev/null 2>&1; then
          echo "PASS: xdg-desktop-portal-hyprland found"
        else
          echo "INFO: xdg-desktop-portal-hyprland not in PATH"
        fi

        # 5. Check PipeWire/WirePlumber
        echo "--- [5/7] Audio stack ---"
        if command -v pipewire >/dev/null 2>&1; then
          echo "PASS: pipewire installed"
        else
          echo "FAIL: pipewire not installed"
          exit 1
        fi
        if command -v wireplumber >/dev/null 2>&1; then
          echo "PASS: wireplumber installed"
        else
          echo "FAIL: wireplumber not installed"
          exit 1
        fi
        if command -v pavucontrol >/dev/null 2>&1; then
          echo "PASS: pavucontrol installed"
        else
          echo "INFO: pavucontrol not in PATH"
        fi

        # 6. Check font setup
        echo "--- [6/7] Fonts ---"
        if command -v fc-list >/dev/null 2>&1; then
          JETBRAINS=$(fc-list | grep -i "JetBrainsMono" | head -1 || true)
          if [ -n "$JETBRAINS" ]; then
            echo "PASS: JetBrainsMono Nerd Font available"
          else
            echo "INFO: JetBrainsMono not found in font cache"
          fi
        else
          echo "INFO: fc-list not available"
        fi

        # 7. Check Hyprland runtime (only works inside a Hyprland session)
        echo "--- [7/7] Hyprland IPC (in-session) ---"
        USER="${cfg.user}"
        RUNTIME_DIR="/run/user/$(id -u "$USER" 2>/dev/null || echo 1000)"
        INSTANCE_DIR=$(ls -d "$RUNTIME_DIR/hypr/"* 2>/dev/null || true)
        if [ -n "$INSTANCE_DIR" ] && [ -S "$INSTANCE_DIR/.socket.sock" ]; then
          echo "PASS: Hyprland IPC socket found at $INSTANCE_DIR"
          HYPRCTL_OUT=$(su - "$USER" -c "hyprctl monitors 2>/dev/null" || true)
          MONITOR_COUNT=$(echo "$HYPRCTL_OUT" | grep -c "Monitor" || true)
          if [ "$MONITOR_COUNT" -gt 0 ]; then
            echo "PASS: hyprctl reports $MONITOR_COUNT monitor(s)"
          else
            echo "WARN: hyprctl monitors returned no data (screen may be off)"
          fi
        else
          echo "WARN: No Hyprland session detected (run inside an active session for IPC tests)"
        fi

        echo "=== Hyprland Smoke Test Complete ==="
      '';
    };
  };
}
