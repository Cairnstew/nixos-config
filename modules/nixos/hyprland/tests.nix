{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  inherit (lib) mkIf;

  wpCfg = cfg.core.windowOpacity;
  wpOverrides = wpCfg.overrides or [ ];

  monitors = config.my.monitors or [ ];

  mkBinaryCheck = name: path: ''
    if [ -x "${path}" ]; then
      echo "  PASS: ${name}"
    else
      echo "  FAIL: ${name} not at ${path}"
      FAILED=$((FAILED + 1))
    fi
  '';

  # Generate L0 assertions for windowOpacity overrides
  overrideAssertions = lib.imap1 (i: o: {
    assertion = o.focused >= 0.0 && o.focused <= 1.0 && o.unfocused >= 0.0 && o.unfocused <= 1.0;
    message = lib.concatStrings [
      "my.desktop.hyprland.core.windowOpacity.overrides[${toString i}]."
      (if o.focused < 0.0 || o.focused > 1.0 then
        "focused (${toString o.focused}) must be between 0.0 and 1.0."
      else
        "unfocused (${toString o.unfocused}) must be between 0.0 and 1.0.")
    ];
  }) wpOverrides;

  btEnabled = config.my.system.bluetooth.enable or false;

  # Bare opacity windowrule detection: "opacity 0.93 0.80" without class/title target
  # is silently ignored by Hyprland. Use decoration:active_opacity/inactive_opacity instead.
  hasBareOpacityRule = lib.any (r:
    lib.hasPrefix "opacity " r && !lib.hasInfix ", " r
  ) cfg.core.extraWindowRules;

  # Bare fullscreen windowrule detection: "fullscreen, class:^(...)$" instead of
  # "fullscreenstate 2, class:^(...)$". Hyprland 0.55+ requires a state value for fullscreen.
  hasBareFullscreenRule = lib.any (r:
    (lib.hasPrefix "fullscreen," r || lib.hasPrefix "fullscreen " r)
    && !lib.hasPrefix "fullscreenstate" r
  ) cfg.core.extraWindowRules;

  mkBluetoothBinCheck = name: bin: lib.optionalString btEnabled ''
    if [ -x "${bin}" ]; then
      pass "${name} binary found"
    else
      fail "${name} not at ${bin}"
    fi
  '';
in
{
  # ── L0: Nix evaluation-time assertions ────────────────────────────────
  assertions = [
    {
      assertion = !cfg.enable || cfg.user != "";
      message = "my.desktop.hyprland.user must be set when hyprland is enabled.";
    }
    {
      assertion = !cfg.enable || !cfg.displayManager.enable
        || cfg.displayManager.greeter == "sddm"
        || config.services.greetd.enable or false;
      message = "greetd must be enabled when my.desktop.hyprland.displayManager is set to greetd.";
    }
    {
      assertion = !cfg.enable || !cfg.displayManager.enable
        || cfg.displayManager.greeter == "sddm"
        || (config.services.greetd.settings.default_session.command or "") != "";
      message = "greetd default_session.command must be set when displayManager is set to greetd.";
    }
    {
      assertion = !cfg.enable || !cfg.idle.enable || cfg.lockscreen.enable;
      message = "my.desktop.hyprland.lockscreen must be enabled for idle to lock the screen.";
    }
    {
      assertion = !cfg.enable || !cfg.wallpapers.enable || !cfg.awww.enable;
      message = "Cannot enable both wallpapers and standalone awww module. Use wallpapers.backend = \"awww\" instead.";
    }
    {
      assertion = !cfg.enable || !wpCfg.enable || (wpCfg.focused >= 0.0 && wpCfg.focused <= 1.0);
      message = "my.desktop.hyprland.core.windowOpacity.focused (${toString wpCfg.focused}) must be between 0.0 and 1.0.";
    }
    {
      assertion = !cfg.enable || !wpCfg.enable || (wpCfg.unfocused >= 0.0 && wpCfg.unfocused <= 1.0);
      message = "my.desktop.hyprland.core.windowOpacity.unfocused (${toString wpCfg.unfocused}) must be between 0.0 and 1.0.";
    }
    {
      assertion = !cfg.enable || !btEnabled || config.services.blueman.enable or false;
      message = "services.blueman must be enabled when my.desktop.hyprland and my.system.bluetooth are both enabled.";
    }
    {
      assertion = !cfg.enable || !wpCfg.enable || !hasBareOpacityRule;
      message = ''
        my.desktop.hyprland.core.extraWindowRules contains a bare 'opacity a b' rule
        without a class: or title: target. Such rules are silently ignored by Hyprland.
        Use decoration:active_opacity and decoration:inactive_opacity for global window
        transparency, or add a class:^(ClassName)$ target for per-window overrides via
        windowOpacity.overrides.
      '';
    }
    {
      assertion = !cfg.enable || !hasBareFullscreenRule;
      message = ''
        my.desktop.hyprland.core.extraWindowRules contains a bare 'fullscreen' rule.
        'fullscreen' and 'fullscreenstate' are NOT valid windowrule types in
        Hyprland 0.55+ — they are bind dispatchers, not window rules.
        Remove the rule entirely; the application's own fullscreen mechanism
        (e.g. gamescope -f) works natively with Hyprland.
      '';
    }
  ] ++ overrideAssertions;

  # ── L1: Health check (manual trigger, also detectable by test-runner) ─
  systemd.services.hyprland-health-check = mkIf cfg.enable {
    description = "Health check for Hyprland compositor and desktop setup";

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -euo pipefail
      PASSED=0
      FAILED=0
      TOTAL=0
      pass() { PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $*"; }
      fail() { FAILED=$((FAILED + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $*"; }
      warn() { echo "  WARN: $*"; }

      echo "=== Hyprland Health Check ==="
      echo ""

      # 1. Config file
      echo "--- [1/6] Config file ---"
      HYPR_CONF="/etc/xdg/hypr/hyprland.conf"
      if [ -f "$HYPR_CONF" ] && [ "$(stat -c%s "$HYPR_CONF")" -gt 100 ]; then
        pass "hyprland.conf exists ($(stat -c%s "$HYPR_CONF") bytes)"
      else
        fail "hyprland.conf missing or too small"
      fi

      # Opacity: verify decoration settings (not bare windowrule)
      if [ "${toString wpCfg.enable}" = 1 ]; then
        if grep -q "active_opacity" "$HYPR_CONF" && grep -q "inactive_opacity" "$HYPR_CONF"; then
          pass "Opacity: decoration:active_opacity/inactive_opacity in config"
        else
          fail "Opacity: decoration:active_opacity/inactive_opacity missing from config"
        fi
        if grep -q "^windowrule = opacity [0-9.]" "$HYPR_CONF" 2>/dev/null; then
          if grep -q "^windowrule = opacity [0-9.].*, " "$HYPR_CONF" 2>/dev/null; then
            pass "Opacity: per-class windowrule overrides use class: targets (valid)"
          fi
          if grep -q "^windowrule = opacity [0-9.]* [0-9.]*$" "$HYPR_CONF" 2>/dev/null; then
            fail "Opacity: bare 'windowrule = opacity' without class target (silently ignored by Hyprland)"
          fi
        fi
      fi

      # 2. Core binaries
      echo "--- [2/6] Core binaries ---"
      for pair in \
        "Hyprland|${pkgs.hyprland}/bin/Hyprland" \
        "hyprctl|${pkgs.hyprland}/bin/hyprctl"; do
        name="''${pair%|*}"
        path="''${pair#*|}"
        if [ -x "$path" ]; then pass "$name"; else fail "$name"; fi
      done

      # 3. Submodule binaries
      echo "--- [3/6] Submodule binaries ---"
      ${lib.optionalString cfg.bar.enable (mkBinaryCheck "waybar" "${pkgs.waybar}/bin/waybar")}
      ${lib.optionalString cfg.launcher.enable (mkBinaryCheck "wofi" "${pkgs.wofi}/bin/wofi")}
      ${lib.optionalString cfg.notifications.enable (mkBinaryCheck "mako" "${pkgs.mako}/bin/mako")}
      ${lib.optionalString cfg.clipboard.enable (mkBinaryCheck "wl-copy" "${pkgs.wl-clipboard}/bin/wl-copy")}
      ${lib.optionalString cfg.screenshot.enable (mkBinaryCheck "grim" "${pkgs.grim}/bin/grim")}
      ${lib.optionalString cfg.screenshot.enable (mkBinaryCheck "slurp" "${pkgs.slurp}/bin/slurp")}
      ${lib.optionalString (cfg.lockscreen.enable && cfg.lockscreen.useHyprlock) (mkBinaryCheck "hyprlock" "${pkgs.hyprlock}/bin/hyprlock")}
      ${lib.optionalString (cfg.lockscreen.enable && !cfg.lockscreen.useHyprlock) (mkBinaryCheck "swaylock" "${pkgs.swaylock}/bin/swaylock")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "hyprpaper") (mkBinaryCheck "hyprpaper" "${pkgs.hyprpaper}/bin/hyprpaper")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "awww") (mkBinaryCheck "awww" "${pkgs.awww}/bin/awww")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "swaybg") (mkBinaryCheck "swaybg" "${pkgs.swaybg}/bin/swaybg")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "mpvpaper") (mkBinaryCheck "mpvpaper" "${pkgs.mpvpaper}/bin/mpvpaper")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "waypaper") (mkBinaryCheck "waypaper" "${pkgs.waypaper}/bin/waypaper")}
      ${lib.optionalString cfg.awww.enable (mkBinaryCheck "awww" "${pkgs.awww}/bin/awww")}
      ${lib.optionalString cfg.awww.enable (mkBinaryCheck "awww-daemon" "${pkgs.awww}/bin/awww-daemon")}

      # Bar config validation
      if [ "${toString cfg.bar.enable}" = 1 ]; then
        if [ -f "/etc/xdg/waybar/config" ]; then
          pass "waybar config file found"
          if python3 -c "import json; json.load(open('/etc/xdg/waybar/config'))" 2>/dev/null; then
            pass "waybar config is valid JSON"
            ETH=$(python3 -c "
import json
c = json.load(open(\"/etc/xdg/waybar/config\"))
net = c.get(\"network\", {})
ef = net.get(\"format-ethernet\", \"\")
print(\"OK\" if ef.strip() else \"BAD\")
" 2>/dev/null || echo "unknown")
            if [ "$ETH" = "OK" ]; then
              pass "waybar network.format-ethernet has meaningful content"
            elif [ "$ETH" = "BAD" ]; then
              fail "waybar network.format-ethernet is empty or whitespace — wired connections show nothing"
            else
              fail "could not check waybar network.format-ethernet"
            fi
            MODULES=$(python3 -c "
import json
c = json.load(open(\"/etc/xdg/waybar/config\"))
mods = c.get(\"modules-left\", []) + c.get(\"modules-center\", []) + c.get(\"modules-right\", [])
missing = [m for m in mods if m.startswith(\"custom/\") or m in c or \"/\" not in m]
print(\"OK\" if not missing else \"MISSING: \" + \",\".join(missing))
")
            if echo "$MODULES" | grep -q "^OK"; then
              pass "waybar all module references have config entries"
            else
              fail "waybar modules missing config: $MODULES"
            fi
          else
            fail "waybar config is not valid JSON"
          fi
        else
          fail "waybar config file not found at /etc/xdg/waybar/config"
        fi
        if [ -f "/etc/xdg/waybar/style.css" ]; then
          pass "waybar style.css exists"
        else
          fail "waybar style.css not found"
        fi
      else
        pass "bar not enabled — skipping bar config checks"
      fi

      # 4. Hyprland process
      echo "--- [4/6] Process ---"
      if pgrep -u "${cfg.user}" Hyprland >/dev/null 2>&1; then
        pass "Hyprland process running (PID $(pgrep -u "${cfg.user}" Hyprland))"
      else
        warn "Hyprland not running (starts after login via greetd)"
      fi

      # 5. IPC + runtime checks
      echo "--- [5/6] IPC & runtime ---"
      RUNTIME_DIR="/run/user/$(id -u "${cfg.user}" 2>/dev/null || echo 1000)"
      INSTANCE_DIR=$(ls -d "$RUNTIME_DIR/hypr/"* 2>/dev/null || true)
      if [ -n "$INSTANCE_DIR" ] && [ -S "$INSTANCE_DIR/.socket.sock" ]; then
        pass "IPC socket at $INSTANCE_DIR"

        HCTL="${pkgs.hyprland}/bin/hyprctl"

        # Config errors
        ERRORS=$($HCTL configerrors 2>/dev/null || true)
        if [ -z "$ERRORS" ]; then
          pass "hyprctl configerrors: clean"
        else
          fail "hyprctl configerrors: $(echo "$ERRORS" | wc -l) error(s)"
          echo "  $ERRORS" | head -5
        fi

        # Monitor count
        MON_COUNT=$($HCTL monitors 2>/dev/null | grep -c "^Monitor" || true)
        if [ "$MON_COUNT" -eq ${builtins.toString (builtins.length monitors)} ]; then
          pass "Monitors: $MON_COUNT (matches config)"
        else
          warn "Monitors: $MON_COUNT runtime vs ${builtins.toString (builtins.length monitors)} in config"
        fi

        # Per-monitor details
        $HCTL monitors 2>/dev/null | grep "^Monitor" | while IFS= read -r line; do
          echo "    $line"
        done

        # Wallpaper daemon
        ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "swaybg") ''
        if pgrep -u "${cfg.user}" swaybg >/dev/null 2>&1; then
          pass "swaybg running"
        else
          warn "swaybg not running"
        fi
        ''}
        ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "hyprpaper") ''
        if pgrep -u "${cfg.user}" hyprpaper >/dev/null 2>&1; then
          pass "hyprpaper running"
        else
          warn "hyprpaper not running"
        fi
        ''}
        ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "awww") ''
        if pgrep -u "${cfg.user}" awww-daemon >/dev/null 2>&1; then
          pass "awww-daemon running"
        else
          warn "awww-daemon not running"
        fi
        ''}
        ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "mpvpaper") ''
        if pgrep -u "${cfg.user}" mpvpaper >/dev/null 2>&1; then
          pass "mpvpaper running"
        else
          warn "mpvpaper not running"
        fi
        ''}

        # Keybinds loaded
        BIND_COUNT=$($HCTL binds 2>/dev/null | grep -c "^bind " || true)
        if [ "$BIND_COUNT" -gt 0 ]; then
          pass "Keybinds: $BIND_COUNT loaded"
        else
          warn "No keybinds detected"
        fi

        # Opacity: runtime values via hyprctl
        if [ "${toString wpCfg.enable}" = 1 ]; then
          ACTIVE_OPACITY=$($HCTL getoption decoration:active_opacity 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
          INACTIVE_OPACITY=$($HCTL getoption decoration:inactive_opacity 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
          if [ "$ACTIVE_OPACITY" = "${toString wpCfg.focused}" ]; then
            pass "Opacity: decoration:active_opacity = $ACTIVE_OPACITY"
          else
            fail "Opacity: decoration:active_opacity = $ACTIVE_OPACITY (expected ${toString wpCfg.focused})"
          fi
          if [ "$INACTIVE_OPACITY" = "${toString wpCfg.unfocused}" ]; then
            pass "Opacity: decoration:inactive_opacity = $INACTIVE_OPACITY"
          else
            fail "Opacity: decoration:inactive_opacity = $INACTIVE_OPACITY (expected ${toString wpCfg.unfocused})"
          fi
          # Window-level opacity via hyprctl clients -j
          CLIENTS_JSON=$($HCTL clients -j 2>/dev/null || echo "[]")
          OPACITY_COUNT=$(echo "$CLIENTS_JSON" | grep -c '"opacity"' || true)
          if [ "$OPACITY_COUNT" -gt 0 ]; then
            pass "Opacity: $OPACITY_COUNT window(s) have opacity set"
          else
            fail "Opacity: NO windows have opacity set (windowrule without target, or decoration settings not applying)"
          fi
        fi
      else
        warn "No Hyprland IPC socket — runtime checks require a running Hyprland session"
      fi

      # 6. Bluetooth
      ${lib.optionalString btEnabled ''
      echo "--- [6/6] Bluetooth ---"
      ${mkBluetoothBinCheck "blueman-applet" "${pkgs.blueman}/bin/blueman-applet"}
      ${mkBluetoothBinCheck "bluetoothctl" "${pkgs.bluez}/bin/bluetoothctl"}
      if grep -q "exec-once = blueman-applet" "$HYPR_CONF" 2>/dev/null; then
        pass "hyprland.conf includes exec-once = blueman-applet"
      else
        fail "hyprland.conf missing exec-once = blueman-applet"
      fi
      if systemctl is-active bluetooth >/dev/null 2>&1; then
        pass "bluetooth service is active"
      else
        warn "bluetooth service not active (expected if no BT hardware)"
      fi
      if command -v blueman-applet >/dev/null 2>&1; then
        pass "blueman-applet in PATH"
      else
        warn "blueman-applet not in PATH (may need to login)"
      fi
      ''}

      echo ""
      echo "=== Result: $TOTAL total, $PASSED passed, $FAILED failed ==="
      [ "$FAILED" -eq 0 ] || exit 1
    '';
  };

  # ── L2: Smoke test (manual trigger) ───────────────────────────────────
  systemd.services.hyprland-smoke-test = mkIf cfg.enable {
    description = "Smoke test for Hyprland configuration and runtime";
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -euo pipefail
      PASSED=0
      FAILED=0
      TOTAL=0
      pass() { PASSED=$((PASSED + 1)); TOTAL=$((TOTAL + 1)); echo "  PASS: $*"; }
      fail() { FAILED=$((FAILED + 1)); TOTAL=$((TOTAL + 1)); echo "  FAIL: $*"; }
      warn() { echo "  WARN: $*"; }

      echo "=== Hyprland Smoke Test ==="
      echo ""

      # ── 1. Config file ──
      echo "--- [1/9] Config ---"
      HYPR_CONF="/etc/xdg/hypr/hyprland.conf"
      if [ -f "$HYPR_CONF" ]; then
        SIZE=$(stat -c%s "$HYPR_CONF")
        if [ "$SIZE" -gt 100 ]; then
          pass "hyprland.conf is $SIZE bytes"
        else
          fail "hyprland.conf is only $SIZE bytes"
        fi
      else
        fail "hyprland.conf not found"
      fi

      # Opacity: verify decoration settings (not bare windowrule)
      if [ "${toString wpCfg.enable}" = 1 ]; then
        if grep -q "active_opacity" "$HYPR_CONF" && grep -q "inactive_opacity" "$HYPR_CONF"; then
          pass "Opacity: decoration:active_opacity/inactive_opacity in config"
        else
          fail "Opacity: decoration:active_opacity/inactive_opacity missing from config"
        fi
        if grep -q "^windowrule = opacity [0-9.]* [0-9.]*$" "$HYPR_CONF" 2>/dev/null; then
          fail "Opacity: bare 'windowrule = opacity' without class target (silently ignored by Hyprland)"
        elif grep -q "^windowrule = opacity [0-9.]" "$HYPR_CONF" 2>/dev/null; then
          pass "Opacity: per-class windowrule overrides use class: targets (valid)"
        fi
      fi

      # ── 2. Required services/config ──
      echo "--- [2/9] Required config ---"
      if [ "${toString (cfg.displayManager.greeter == "greetd")}" = 1 ]; then
        GREETD_CMD="${config.services.greetd.settings.default_session.command or ""}"
        if echo "$GREETD_CMD" | grep -qi "Hyprland"; then
          pass "greetd launches Hyprland"
        else
          warn "greetd command may not reference Hyprland directly"
        fi
      else
        pass "using SDDM display manager"
      fi

      # ── 3. Core binaries ──
      echo "--- [3/9] Core binaries ---"
      for pair in \
        "Hyprland|${pkgs.hyprland}/bin/Hyprland" \
        "hyprctl|${pkgs.hyprland}/bin/hyprctl"; do
        name="''${pair%|*}"
        path="''${pair#*|}"
        if [ -x "$path" ]; then pass "$name"; else fail "$name"; fi
      done

      # ── 4. Submodule binaries ──
      echo "--- [4/9] Submodule binaries ---"
      ${lib.optionalString cfg.bar.enable (mkBinaryCheck "waybar" "${pkgs.waybar}/bin/waybar")}
      ${lib.optionalString cfg.launcher.enable (mkBinaryCheck "wofi" "${pkgs.wofi}/bin/wofi")}
      ${lib.optionalString cfg.notifications.enable (mkBinaryCheck "mako" "${pkgs.mako}/bin/mako")}
      ${lib.optionalString cfg.clipboard.enable (mkBinaryCheck "wl-copy" "${pkgs.wl-clipboard}/bin/wl-copy")}
      ${lib.optionalString cfg.screenshot.enable (mkBinaryCheck "grim" "${pkgs.grim}/bin/grim")}
      ${lib.optionalString cfg.screenshot.enable (mkBinaryCheck "slurp" "${pkgs.slurp}/bin/slurp")}
      ${lib.optionalString (cfg.lockscreen.enable && cfg.lockscreen.useHyprlock) (mkBinaryCheck "hyprlock" "${pkgs.hyprlock}/bin/hyprlock")}
      ${lib.optionalString (cfg.lockscreen.enable && !cfg.lockscreen.useHyprlock) (mkBinaryCheck "swaylock" "${pkgs.swaylock}/bin/swaylock")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "hyprpaper") (mkBinaryCheck "hyprpaper" "${pkgs.hyprpaper}/bin/hyprpaper")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "awww") (mkBinaryCheck "awww" "${pkgs.awww}/bin/awww")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "awww") (mkBinaryCheck "awww-daemon" "${pkgs.awww}/bin/awww-daemon")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "swaybg") (mkBinaryCheck "swaybg" "${pkgs.swaybg}/bin/swaybg")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "mpvpaper") (mkBinaryCheck "mpvpaper" "${pkgs.mpvpaper}/bin/mpvpaper")}
      ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "waypaper") (mkBinaryCheck "waypaper" "${pkgs.waypaper}/bin/waypaper")}
      ${lib.optionalString cfg.awww.enable (mkBinaryCheck "awww" "${pkgs.awww}/bin/awww")}
      ${lib.optionalString cfg.awww.enable (mkBinaryCheck "awww-daemon" "${pkgs.awww}/bin/awww-daemon")}

      # Bar config validation
      if [ "${toString cfg.bar.enable}" = 1 ]; then
        WAYBAR_CFG="/etc/xdg/waybar/config"
        if [ -f "$WAYBAR_CFG" ]; then
          pass "waybar config file found"
          if python3 -c "import json; json.load(open('$WAYBAR_CFG'))" 2>/dev/null; then
            pass "waybar config is valid JSON"
            ETH=$(python3 -c "
import json
c = json.load(open(\"$WAYBAR_CFG\"))
net = c.get(\"network\", {})
ef = net.get(\"format-ethernet\", \"\")
print(\"OK\" if ef.strip() else \"BAD\")
" 2>/dev/null || echo "unknown")
            if [ "$ETH" = "OK" ]; then
              pass "waybar network.format-ethernet has meaningful content"
            elif [ "$ETH" = "BAD" ]; then
              fail "waybar network.format-ethernet is empty or whitespace"
            else
              fail "could not check waybar network.format-ethernet"
            fi
          else
            fail "waybar config is not valid JSON"
          fi
        else
          fail "waybar config not found at $WAYBAR_CFG"
        fi
        if [ -f "/etc/xdg/waybar/style.css" ]; then
          pass "waybar style.css exists"
        else
          fail "waybar style.css not found"
        fi
      else
        pass "bar not enabled — skipping bar config checks"
      fi

      # ── 5. Portals ──
      echo "--- [5/9] Portals ---"
      if command -v xdg-desktop-portal-hyprland >/dev/null 2>&1; then
        pass "xdg-desktop-portal-hyprland found"
      else
        warn "xdg-desktop-portal-hyprland not in PATH"
      fi

      # ── 6. Audio ──
      echo "--- [6/9] Audio ---"
      ${mkBinaryCheck "pipewire" "${pkgs.pipewire}/bin/pipewire"}
      ${mkBinaryCheck "wireplumber" "${pkgs.wireplumber}/bin/wireplumber"}

      # ── 7. Fonts ──
      echo "--- [7/9] Fonts ---"
      if command -v fc-list >/dev/null 2>&1; then
        JETBRAINS=$(fc-list | grep -i "JetBrainsMono" | head -1 || true)
        if [ -n "$JETBRAINS" ]; then
          pass "JetBrainsMono Nerd Font available"
        else
          warn "JetBrainsMono not found in font cache"
        fi
      else
        warn "fc-list not available"
      fi

      # ── 8. IPC + runtime ──
      echo "--- [8/9] IPC & runtime ---"
      USER="${cfg.user}"
      RUNTIME_DIR="/run/user/$(id -u "$USER" 2>/dev/null || echo 1000)"
      INSTANCE_DIR=$(ls -d "$RUNTIME_DIR/hypr/"* 2>/dev/null || true)
      if [ -n "$INSTANCE_DIR" ] && [ -S "$INSTANCE_DIR/.socket.sock" ]; then
        pass "IPC socket at $INSTANCE_DIR"

        HCTL="${pkgs.hyprland}/bin/hyprctl"

        # Config errors
        ERRORS=$($HCTL configerrors 2>/dev/null || true)
        if [ -z "$ERRORS" ]; then
          pass "hyprctl configerrors: clean"
        else
          fail "hyprctl configerrors has errors"
          echo "  $ERRORS"
        fi

        # Monitors
        MON_OUT=$($HCTL monitors 2>/dev/null || true)
        MON_COUNT=$(echo "$MON_OUT" | grep -c "^Monitor" || true)
        pass "hyprctl monitors: $MON_COUNT detected"
        echo "  $MON_OUT" | grep "^Monitor" | sed 's/^/    /'

        # Active window
        ACTIVE=$($HCTL activewindow 2>/dev/null | head -3 || true)
        if [ -n "$ACTIVE" ]; then
          pass "Active window query works"
          echo "  $ACTIVE" | head -1 | sed 's/^/    /'
        fi

        # Clients
        CLIENT_COUNT=$($HCTL clients 2>/dev/null | grep -c "Window " || true)
        pass "hyprctl clients: $CLIENT_COUNT window(s)"

        # Keybinds
        BIND_COUNT=$($HCTL binds 2>/dev/null | grep -c "^bind " || true)
        if [ "$BIND_COUNT" -gt 0 ]; then
          pass "Keybinds: $BIND_COUNT loaded"
        else
          warn "No keybinds detected"
        fi

        # Window rules
        ${lib.optionalString (wpCfg.enable || cfg.core.extraWindowRules != [ ]) ''
        RULE_COUNT=$($HCTL getoption windowrule 2>/dev/null | grep -c "windowrule" || true)
        if [ "$RULE_COUNT" -gt 0 ]; then
          pass "Window rules: $RULE_COUNT configured"
        else
          warn "No window rules found (may be expected if none configured)"
        fi
        ''}

        # Opacity: runtime values via hyprctl
        if [ "${toString wpCfg.enable}" = 1 ]; then
          ACTIVE_OPACITY=$($HCTL getoption decoration:active_opacity 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
          INACTIVE_OPACITY=$($HCTL getoption decoration:inactive_opacity 2>/dev/null | head -1 | awk '{print $2}' || echo "unknown")
          if [ "$ACTIVE_OPACITY" = "${toString wpCfg.focused}" ]; then
            pass "Opacity: decoration:active_opacity = $ACTIVE_OPACITY"
          else
            fail "Opacity: decoration:active_opacity = $ACTIVE_OPACITY (expected ${toString wpCfg.focused})"
          fi
          if [ "$INACTIVE_OPACITY" = "${toString wpCfg.unfocused}" ]; then
            pass "Opacity: decoration:inactive_opacity = $INACTIVE_OPACITY"
          else
            fail "Opacity: decoration:inactive_opacity = $INACTIVE_OPACITY (expected ${toString wpCfg.unfocused})"
          fi
          CLIENTS_JSON=$($HCTL clients -j 2>/dev/null || echo "[]")
          OPACITY_COUNT=$(echo "$CLIENTS_JSON" | grep -c '"opacity"' || true)
          if [ "$OPACITY_COUNT" -gt 0 ]; then
            pass "Opacity: $OPACITY_COUNT window(s) have opacity set"
          else
            fail "Opacity: NO windows have opacity set (windowrule without target, or decoration settings not applying)"
          fi
        fi
      else
        warn "No Hyprland session — IPC checks require a running Hyprland session"
      fi

      # ── 9. Bluetooth ──
      ${lib.optionalString btEnabled ''
      echo "--- [9/9] Bluetooth ---"
      ${mkBluetoothBinCheck "blueman-applet" "${pkgs.blueman}/bin/blueman-applet"}
      ${mkBluetoothBinCheck "bluetoothctl" "${pkgs.bluez}/bin/bluetoothctl"}
      if grep -q "exec-once = blueman-applet" "$HYPR_CONF" 2>/dev/null; then
        pass "hyprland.conf includes exec-once = blueman-applet"
      else
        fail "hyprland.conf missing exec-once = blueman-applet"
      fi
      if systemctl is-active bluetooth >/dev/null 2>&1; then
        pass "bluetooth service is active"
      else
        warn "bluetooth service not active (expected if no BT hardware)"
      fi
      ''}

      echo ""
      echo "=== Result: $TOTAL total, $PASSED passed, $FAILED failed ==="
      [ "$FAILED" -eq 0 ] || exit 1
    '';
  };
}
