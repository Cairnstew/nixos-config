{ config, pkgs, lib, ... }:
let
  cfg = config.my.desktop.hyprland;
  coreCfg = cfg.core;

  mkSwaybgFlag = img:
    (lib.optionalString (img.output != null) "-o ${lib.escapeShellArg img.output} ")
    + "-i ${lib.escapeShellArg img.path}";

  hasWallpaperContent = cfg.wallpapers.enable && (
    cfg.wallpapers.backend == "hyprpaper"
    || cfg.wallpapers.backend == "waypaper"
    || cfg.wallpapers.images != [ ]
  );

  monitorLines = builtins.map
    (m:
      let
        res = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
        pos = "${toString m.x}x${toString m.y}";
        scale = lib.removeSuffix ".000000" (toString m.scale);
        disabled = if m.enabled then "" else ",disable";
      in
      "monitor = ${m.name},${res},${pos},${scale}${disabled}"
    )
    (builtins.filter (m: m.name != "") config.my.monitors);

  transformLines = builtins.map
    (m:
      "monitor = ${m.name},transform,${toString m.transform}"
    )
    (builtins.filter (m: m.name != "" && m.transform != 0 && m.enabled) config.my.monitors);

  workspaceLines = builtins.map
    (m:
      "workspace = ${m.workspace}, monitor:${m.name}"
    )
    (builtins.filter (m: m.name != "" && m.enabled) config.my.monitors);

  mkWorkspaceExecOnce = entry:
    let
      ws = "[workspace ${entry.workspace}${lib.optionalString entry.silent " silent"}]";
    in
    "exec-once = ${ws} ${entry.command}";

  mkWorkspaceTarget = entry:
    let
      parts = lib.optional (entry.class != null) "class:^(${entry.class})$"
        ++ lib.optional (entry.title != null) "title:^(${entry.title})$";
    in
    lib.concatStringsSep ", " parts;

  mkWindowRulesForEntry = entry:
    let
      target = mkWorkspaceTarget entry;
    in
    lib.optional (target != "" && (entry.floating || entry.size != null || entry.position != null)) "windowrule = float, ${target}"
    ++ lib.optional (target != "" && entry.size != null) "windowrule = size ${toString entry.size.width} ${toString entry.size.height}, ${target}"
    ++ lib.optional (target != "" && entry.position != null) "windowrule = move ${toString entry.position.x} ${toString entry.position.y}, ${target}";

  workspaceExecOnceLines = builtins.map mkWorkspaceExecOnce cfg.core.workspaceStartup;

  workspaceWindowRuleLines = lib.concatLists (builtins.map mkWindowRulesForEntry cfg.core.workspaceStartup);

  defaultHyprlandConf = ''
    # ── Monitors ───────────────────────────────────────────────────────────
    ${if config.my.monitors != [ ] && cfg.useMonitors then
      (lib.concatStringsSep "\n" monitorLines)
      + lib.optionalString (builtins.any (m: m.transform != 0 && m.enabled) config.my.monitors)
        ("\n" + lib.concatStringsSep "\n" transformLines)
      else
      "monitor = ,preferred,auto,1"
    }

    # ── Workspace assignments ─────────────────────────────────────────────
    ${lib.optionalString (config.my.monitors != [ ] && cfg.useMonitors)
      (lib.concatStringsSep "\n" workspaceLines)}

    # ── Autostart ──────────────────────────────────────────────────────────
    ${lib.optionalString cfg.idle.enable ''
    exec-once = systemctl --user start hypridle.service
    ''}
    ${lib.optionalString cfg.notifications.enable ''
    exec-once = mako
    ''}
    ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "hyprpaper") ''
    exec-once = hyprpaper -c /etc/xdg/hypr/hyprpaper.conf
    ''}
    ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "waypaper") ''
    exec-once = waypaper --restore
    ''}
    ${lib.optionalString (cfg.wallpapers.enable && cfg.wallpapers.backend == "swaybg" && cfg.wallpapers.images != []) ''
    exec-once = swaybg ${lib.concatStringsSep " " (builtins.map mkSwaybgFlag cfg.wallpapers.images)} -m fill
    ''}
    ${lib.optionalString cfg.bar.enable ''
    exec-once = waybar
    ''}
    ${lib.optionalString config.my.system.bluetooth.enable ''
    exec-once = blueman-applet
    ''}
    ${lib.optionalString cfg.utilities.enable ''
    exec-once = nm-applet
    ''}
    exec-once = /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1
    ${lib.concatMapStringsSep "\n" (cmd: "exec-once = ${cmd}") cfg.core.extraExecOnce}
    ${lib.concatStringsSep "\n" workspaceExecOnceLines}

    # ── Environment variables ───────────────────────────────────────────────
    env = XDG_CURRENT_DESKTOP,Hyprland
    env = XDG_SESSION_TYPE,wayland
    env = XDG_SESSION_DESKTOP,Hyprland
    env = GTK_THEME,Adwaita:dark
    env = XCURSOR_THEME,Adwaita
    env = XCURSOR_SIZE,24
    ${lib.optionalString cfg.nvidia.enable ''
    env = LIBVA_DRIVER_NAME,nvidia
    env = __GLX_VENDOR_LIBRARY_NAME,nvidia
    env = WLR_NO_HARDWARE_CURSORS,1
    ''}

    # ── General ────────────────────────────────────────────────────────────
    general {
        gaps_in          = 4
        gaps_out         = 8
        border_size      = 2
        col.active_border   = rgba(89b4faff) rgba(cba6f7ff) 45deg
        col.inactive_border = rgba(313244ff)
        layout           = dwindle
        resize_on_border = true
    }

    # ── Decoration ─────────────────────────────────────────────────────────
    decoration {
        rounding = 8
        ${lib.optionalString (cfg.core.windowOpacity.enable) "active_opacity   = ${toString cfg.core.windowOpacity.focused}"}
        ${lib.optionalString (cfg.core.windowOpacity.enable) "inactive_opacity = ${toString cfg.core.windowOpacity.unfocused}"}
        blur {
            enabled = true
            size    = 6
            passes  = 2
        }
        shadow {
            enabled      = true
            range        = 12
            render_power = 3
            color        = rgba(1a1a2ecc)
        }
    }

    # ── Animations ─────────────────────────────────────────────────────────
    animations {
        enabled = true
    }

    # ── Input ──────────────────────────────────────────────────────────────
    input {
        kb_layout    = us
        follow_mouse = 1
        sensitivity  = 0
        touchpad {
            natural_scroll    = true
            tap-to-click      = true
            drag_lock         = true
        }
    }

    # ── Layout ─────────────────────────────────────────────────────────────
    dwindle {
        preserve_split = true
    }

    master {
        new_status = master
    }

    # ── Misc ───────────────────────────────────────────────────────────────
    misc {
        ${lib.optionalString hasWallpaperContent "force_default_wallpaper = 0"}
        disable_hyprland_logo   = true
    }

    ${lib.optionalString coreCfg.debug.enable ''
    # ── Debug / Logging ─────────────────────────────────────────────────────
    debug {
        disable_logs   = ${if coreCfg.debug.disableLogs then "true" else "false"}
        gl_debugging   = ${if coreCfg.debug.glDebugging then "true" else "false"}
    }
    ''}

    # ── Window rules ───────────────────────────────────────────────────────
    ${lib.concatStringsSep "\n" workspaceWindowRuleLines}
    ${lib.concatStringsSep "\n" (builtins.map (o: "windowrule = opacity ${toString o.focused} ${toString o.unfocused}, class:^(${o.class})$") cfg.core.windowOpacity.overrides)}
    ${lib.concatMapStringsSep "\n" (r: "windowrule = ${r}") cfg.core.extraWindowRules}

    # ── Keybinds ───────────────────────────────────────────────────────────
    $mod = SUPER

    # Core
    bind = $mod,       Return, exec, ${lib.getExe cfg.terminal}
    bind = $mod,       Q,      killactive
    bind = $mod SHIFT, E,      exit
    bind = $mod,       F,      fullscreen, 0
    bind = $mod SHIFT, F,      togglefloating
    bind = $mod,       P,      pseudo

    # Launcher / utilities
    ${lib.optionalString cfg.launcher.enable ''
    bind = $mod,       D,      exec, wofi --show drun
    ''}
    bind = $mod,       E,      exec, thunar
    ${lib.optionalString cfg.lockscreen.enable ''
    bind = $mod,       L,      exec, swaylock
    ''}
    ${lib.optionalString cfg.screenshot.enable ''
    bind = $mod SHIFT, S,      exec, grim -g "$(slurp)" - | wl-copy
    bind = ,           Print,  exec, grim ~/Pictures/screenshot-$(date +%F_%T).png
    ''}
    ${lib.optionalString cfg.colorpicker.enable ''
    bind = $mod SHIFT, P,      exec, hyprpicker -a
    ''}

    # Volume
    bindel = , XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindl  = , XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindl  = , XF86AudioMicMute,      exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

    # Brightness
    bindel = , XF86MonBrightnessUp,   exec, brightnessctl set 5%+
    bindel = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

    # Focus
    bind = $mod, left,  movefocus, l
    bind = $mod, right, movefocus, r
    bind = $mod, up,    movefocus, u
    bind = $mod, down,  movefocus, d
    bind = $mod, H,     movefocus, l
    bind = $mod, L,     movefocus, r
    bind = $mod, K,     movefocus, u
    bind = $mod, J,     movefocus, d

    # Move
    bind = $mod SHIFT, left,  movewindow, l
    bind = $mod SHIFT, right, movewindow, r
    bind = $mod SHIFT, up,    movewindow, u
    bind = $mod SHIFT, down,  movewindow, d

    # Resize
    binde = $mod CTRL, right, resizeactive,  20 0
    binde = $mod CTRL, left,  resizeactive, -20 0
    binde = $mod CTRL, up,    resizeactive,  0 -20
    binde = $mod CTRL, down,  resizeactive,  0  20

    # Workspaces 1-9
    ${lib.concatMapStringsSep "\n" (n: ''
    bind = $mod,       ${toString n}, workspace,       ${toString n}
    bind = $mod SHIFT, ${toString n}, movetoworkspace, ${toString n}
    '') (lib.range 1 9)}

    # Scratchpad
    bind = $mod,       S, togglespecialworkspace, magic
    bind = $mod SHIFT, S, movetoworkspace,        special:magic

    # Mouse binds
    bindm = $mod, mouse:272, movewindow
    bindm = $mod, mouse:273, resizewindow
  '';
in
{
  config = lib.mkIf (cfg.enable && coreCfg.enable) {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      HYPRLAND_CONFIG = "/etc/xdg/hypr/hyprland.conf";
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

    environment.etc."xdg/hypr/hyprland.conf".text = defaultHyprlandConf;

    users.users.${cfg.user}.extraGroups = [ "video" "audio" "input" ];
  };
}
