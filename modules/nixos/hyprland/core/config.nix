{ config, pkgs, lib, ... }:
let
  cfg = config.my.desktop.hyprland;
  coreCfg = cfg.core;

  mkSwaybgFlag = img:
    (lib.optionalString (img.output != null) "-o ${lib.escapeShellArg img.output} ")
    + "-i ${lib.escapeShellArg img.path}";

  # Lua string literal (double-quoted). lib.escapeShellArg is shell quoting
  # and is NOT valid here: it leaves simple words bare (a Lua variable
  # reference) and single-quotes the rest.
  luaStr = s:
    "\"" + builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s + "\"";

  hasWallpaperContent = cfg.wallpapers.enable && (
    cfg.wallpapers.backend == "hyprpaper"
      || cfg.wallpapers.backend == "waypaper"
      || cfg.wallpapers.images != [ ]
  );

  # Lua string literal for generated code. Nix ''...'' strings pass through
  # literally except for ''${'' escapes, so Lua ${...} interpolation must be
  # spelled ''${ in the Nix source (only the grim binds use it).
  monitorLines = builtins.map
    (m:
      let
        res = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
        pos = "${toString m.x}x${toString m.y}";
        scale = lib.removeSuffix ".000000" (toString m.scale);
      in
      if m.enabled then
        ''hl.monitor({ output = "${m.name}", mode = "${res}", position = "${pos}", scale = ${scale}, transform = ${toString m.transform} })''
      else
        ''hl.monitor({ output = "${m.name}", disabled = true })''
    )
    (builtins.filter (m: m.name != "") config.my.monitors);

  workspaceLines = builtins.map
    (m:
      ''hl.workspace_rule({ workspace = "${m.workspace}", monitor = "${m.name}" })''
    )
    (builtins.filter (m: m.name != "" && m.enabled) config.my.monitors);

  mkWorkspaceExecOnce = entry:
    let
      rules = "{ workspace = \"${entry.workspace}\""
        + lib.optionalString entry.silent ", silent = true" + " }";
    in
    ''hl.exec_cmd(${luaStr entry.command}, ${rules})'';

  mkWorkspaceMatch = entry:
    let
      parts = lib.optional (entry.class != null) ''class = "^(${entry.class})$"''
        ++ lib.optional (entry.title != null) ''title = "^(${entry.title})$"'';
    in
    lib.concatStringsSep ", " parts;

  mkWindowRulesForEntry = entry:
    let
      match = mkWorkspaceMatch entry;
      hasFloat = entry.floating || entry.size != null || entry.position != null;
    in
    lib.optional (match != "" && hasFloat)
      ''hl.window_rule({ match = { ${match} }, float = true })''
    ++ lib.optional (match != "" && entry.size != null)
      ''hl.window_rule({ match = { ${match} }, size = "${toString entry.size.width} ${toString entry.size.height}" })''
    ++ lib.optional (match != "" && entry.position != null)
      ''hl.window_rule({ match = { ${match} }, move = "${toString entry.position.x} ${toString entry.position.y}" })'';

  workspaceExecOnceLines = builtins.map mkWorkspaceExecOnce cfg.core.workspaceStartup;

  workspaceWindowRuleLines = lib.concatLists (builtins.map mkWindowRulesForEntry cfg.core.workspaceStartup);

  # Hyprland 0.57 dropped hyprlang (.conf) configs; this is now a Lua file
  # (the `hl.*` API documented in the wiki and in the shipped hl.meta.lua
  # stubs). Note Lua comments are `--`, not `#`.
  defaultHyprlandConf = ''
    -- ── Monitors ───────────────────────────────────────────────────────────
    ${if config.my.monitors != [ ] && cfg.useMonitors then
      lib.concatStringsSep "\n" monitorLines
    else
      ''hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })''
    }

    -- ── Workspace assignments ─────────────────────────────────────────────
    ${lib.optionalString (config.my.monitors != [ ] && cfg.useMonitors)
      (lib.concatStringsSep "\n" workspaceLines)}

    -- ── Autostart ──────────────────────────────────────────────────────────
    -- Mark the compositor session in systemd. graphical-session.target is
    -- RefuseManualStart and is normally started by a display-manager session
    -- manager; greetd launches Hyprland directly, so nothing did — which left
    -- xdg-desktop-portal inactive (Requisite=graphical-session.target) and OBS
    -- without its PipeWire screen/window sources. Import the Wayland env first
    -- so the portal units see WAYLAND_DISPLAY.
    hl.on("hyprland.start", function()
      hl.exec_cmd(${luaStr "${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && ${pkgs.systemd}/bin/systemctl --user start hyprland-session.target"})
    ${lib.optionalString cfg.idle.enable ''
      hl.exec_cmd(${luaStr "systemctl --user start hypridle.service"})
    ''}
    ${lib.optionalString cfg.notifications.enable ''
      hl.exec_cmd(${luaStr "mako"})
    ''}
    ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "hyprpaper") ''
      hl.exec_cmd(${luaStr "hyprpaper -c /etc/xdg/hypr/hyprpaper.conf"})
    ''}
    ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "waypaper") ''
      hl.exec_cmd(${luaStr "waypaper --restore"})
    ''}
    ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "swaybg" && cfg.wallpapers.images != []) ''
      hl.exec_cmd(${luaStr "swaybg ${lib.concatStringsSep " " (builtins.map mkSwaybgFlag cfg.wallpapers.images)} -m fill"})
    ''}
    ${lib.optionalString cfg.bar.enable ''
      hl.exec_cmd(${luaStr "systemctl --user start waybar"})
    ''}
    ${lib.optionalString config.my.system.bluetooth.enable ''
      hl.exec_cmd(${luaStr "blueman-applet"})
    ''}
    ${lib.optionalString cfg.utilities.enable ''
      hl.exec_cmd(${luaStr "nm-applet"})
    ''}
      hl.exec_cmd(${luaStr "/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1"})
    ${lib.concatMapStringsSep "\n" (cmd: "  hl.exec_cmd(${luaStr cmd})") cfg.core.extraExecOnce}
    ${lib.concatStringsSep "\n" workspaceExecOnceLines}
    end)

    -- ── Environment variables ───────────────────────────────────────────────
    hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
    hl.env("XDG_SESSION_TYPE", "wayland")
    hl.env("XDG_SESSION_DESKTOP", "Hyprland")
    hl.env("GTK_THEME", "Adwaita:dark")
    hl.env("XCURSOR_THEME", "Adwaita")
    hl.env("XCURSOR_SIZE", "24")
    ${lib.optionalString cfg.nvidia.enable ''
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("WLR_NO_HARDWARE_CURSORS", "1")
    ''}

    -- ── General ────────────────────────────────────────────────────────────
    hl.config({
      general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
          active_border = { colors = {"rgba(89b4faff)", "rgba(cba6f7ff)"}, angle = 45 },
          inactive_border = "rgba(313244ff)",
        },
        layout = "dwindle",
        resize_on_border = true,
      },
    })

    -- ── Animations ─────────────────────────────────────────────────────────
    hl.config({ animations = { enabled = true } })

    -- ── Input ──────────────────────────────────────────────────────────────
    hl.config({
      input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        ${lib.optionalString (coreCfg.accelProfile != null) ''accel_profile = "${coreCfg.accelProfile}",''}
        touchpad = {
          natural_scroll = true,
          tap_to_click = true,
          drag_lock = true,
        },
      },
    })

    -- ── Layout ─────────────────────────────────────────────────────────────
    hl.config({ dwindle = { preserve_split = true } })
    hl.config({ master = { new_status = "master" } })

    -- ── Misc ───────────────────────────────────────────────────────────────
    hl.config({
      misc = {
        ${lib.optionalString hasWallpaperContent "force_default_wallpaper = 0,"}
        disable_hyprland_logo = true,
      },
    })

    ${lib.optionalString coreCfg.debug.enable ''
    -- ── Debug / Logging ─────────────────────────────────────────────────────
    hl.config({
      debug = {
        disable_logs = ${if coreCfg.debug.disableLogs then "true" else "false"},
        gl_debugging = ${if coreCfg.debug.glDebugging then "true" else "false"},
      },
    })
    ''}

    -- ── Window rules ───────────────────────────────────────────────────────
    ${lib.concatStringsSep "\n" workspaceWindowRuleLines}
    ${lib.concatStringsSep "\n" cfg.core.extraWindowRules}

    -- ── Keybinds ───────────────────────────────────────────────────────────
    local mainMod = "SUPER"

    -- Core
    hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(${luaStr (lib.getExe cfg.terminal)}))
    hl.bind(mainMod .. " + Q", hl.dsp.window.close())
    hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
    hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(0))
    hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
    hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())

    -- Launcher / utilities
    ${lib.optionalString cfg.launcher.enable ''
    hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(${luaStr "wofi --show drun"}))
    ''}
    hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(${luaStr "thunar"}))
    ${lib.optionalString cfg.lockscreen.enable ''
    hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(${luaStr "swaylock"}))
    ''}
    ${lib.optionalString cfg.screenshot.enable ''
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(${luaStr ''grim -g "$(slurp)" - | wl-copy''}))
    hl.bind("Print", hl.dsp.exec_cmd(${luaStr ''grim ~/Pictures/screenshot-$(date +%F_%T).png''}))
    ''}
    ${lib.optionalString cfg.colorpicker.enable ''
    hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(${luaStr "hyprpicker -a"}))
    ''}

    -- Volume
    hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(${luaStr "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"}), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(${luaStr "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"}), { locked = true, repeating = true })
    hl.bind("XF86AudioMute", hl.dsp.exec_cmd(${luaStr "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"}), { locked = true })
    hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(${luaStr "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"}), { locked = true })

    -- Brightness
    hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(${luaStr "brightnessctl set 5%+"}), { locked = true, repeating = true })
    hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(${luaStr "brightnessctl set 5%-"}), { locked = true, repeating = true })

    -- Media
    hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(${luaStr "playerctl play-pause"}), { locked = true })
    hl.bind("XF86AudioNext", hl.dsp.exec_cmd(${luaStr "playerctl next"}), { locked = true })
    hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(${luaStr "playerctl previous"}), { locked = true })
    hl.bind("XF86AudioStop", hl.dsp.exec_cmd(${luaStr "playerctl stop"}), { locked = true })

    -- Host-local binds (my.desktop.hyprland.core.extraBinds). Emitted last so a
    -- host CAN intentionally shadow one of the binds above. Each entry is a
    -- complete Lua statement (e.g. an hl.bind call); `mainMod` is in scope.
    ${lib.concatStringsSep "\n" coreCfg.extraBinds}

    -- Focus
    hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))
    hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
    hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
    hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
    hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

    -- Move
    hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
    hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
    hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
    hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

    -- Resize
    hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 20, y = 0 }), { repeating = true })
    hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -20, y = 0 }), { repeating = true })
    hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -20 }), { repeating = true })
    hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 20 }), { repeating = true })

    -- Workspaces 1-9
    ${lib.concatMapStringsSep "\n" (n: ''
    hl.bind(mainMod .. " + ${toString n}", hl.dsp.focus({ workspace = ${toString n} }))
    hl.bind(mainMod .. " + SHIFT + ${toString n}", hl.dsp.window.move({ workspace = ${toString n} }))
    '') (lib.range 1 9)}

    -- Scratchpad
    hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
    hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

    -- Mouse binds
    hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
    hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
  '';
in
{
  config = lib.mkIf (cfg.enable && coreCfg.enable) {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      HYPRLAND_CONFIG = "/etc/xdg/hypr/hyprland.lua";
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    } // lib.optionalAttrs coreCfg.debug.trace {
      HYPRLAND_TRACE = "1";
      AQ_TRACE = "1";
    };

    environment.systemPackages = with pkgs; [
      cfg.terminal
    ] ++ cfg.extraPackages;

    environment.etc."xdg/hypr/hyprland.lua".text = defaultHyprlandConf;

    # Session target the compositor starts (see the autostart hl.on above).
    # It pulls in graphical-session.target as a dependency — the only way to
    # start that RefuseManualStart unit — so portals and every unit wired to
    # hyprland-session.target (pyprland, waybar, wallpapers) actually run.
    systemd.user.targets.hyprland-session = {
      description = "Hyprland compositor session";
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
    };

    users.users.${cfg.user}.extraGroups = [ "video" "audio" "input" ];
  };
}
