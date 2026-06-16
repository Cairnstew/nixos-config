{ config, pkgs, lib, ... }:
let
  cfg = config.my.desktop.hyprland;

  # Generate monitor lines from my.monitors — supports transform/orientation
  monitorLines = builtins.map
    (m:
      let
        res = "${toString m.width}x${toString m.height}@${toString m.refreshRate}";
        pos = "${toString m.x}x${toString m.y}";
        # Nix formats floats as 1.000000; strip the trailing zeros for cleaner output
        scale = lib.removeSuffix ".000000" (toString m.scale);
        disabled = if m.enabled then "" else ",disable";
      in
      "monitor = ${m.name},${res},${pos},${scale}${disabled}"
    )
    (builtins.filter (m: m.name != "") config.my.monitors);

  # Generate separate transform lines (Hyprland 0.44+ requires this)
  transformLines = builtins.map
    (m:
      "monitor = ${m.name},transform,${toString m.transform}"
    )
    (builtins.filter (m: m.name != "" && m.transform != 0 && m.enabled) config.my.monitors);

  # Generate workspace→monitor bindings from my.monitors
  workspaceLines = builtins.map
    (m:
      "workspace = ${m.workspace}, monitor:${m.name}"
    )
    (builtins.filter (m: m.name != "" && m.enabled) config.my.monitors);

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
    exec-once = waybar
    exec-once = mako
    exec-once = hyprpaper
    exec-once = /run/current-system/sw/libexec/polkit-gnome-authentication-agent-1

    # ── Environment variables ───────────────────────────────────────────────
    env = XDG_CURRENT_DESKTOP,Hyprland
    env = XDG_SESSION_TYPE,wayland
    env = XDG_SESSION_DESKTOP,Hyprland
    env = GTK_THEME,Adwaita:dark
    env = XCURSOR_THEME,Adwaita
    env = XCURSOR_SIZE,24
    ${lib.optionalString cfg.nvidia ''
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
        bezier  = snappy, 0.05, 0.9, 0.1, 1.05
        animation = windows,     1, 4,  snappy, slide
        animation = windowsOut,  1, 4,  default, popin 80%
        animation = border,      1, 8,  default
        animation = fade,        1, 6,  default
        animation = workspaces,  1, 5,  snappy, slidevert
    }

    # ── Input ──────────────────────────────────────────────────────────────
    input {
        kb_layout    = gb
        follow_mouse = 1
        sensitivity  = 0
        touchpad {
            natural_scroll    = true
            tap-to-click      = true
            drag_lock         = true
        }
    }

    # ── Gestures ───────────────────────────────────────────────────────────
    gesture {
        workspace_swipe = true
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
        force_default_wallpaper = 0
        disable_hyprland_logo   = true
    }

    # ── Window rules ───────────────────────────────────────────────────────
    windowrule = float, class:^(pavucontrol)$
    windowrule = float, class:^(nm-connection-editor)$
    windowrule = float, class:^(thunar)$, title:^(?!.* - Thunar$).*
    windowrule = float, class:^(imv)$
    windowrule = float, class:^(mpv)$
    windowrule = center, floating:1
    windowrule = idleinhibit focus, class:^(mpv)$

    # ── Keybinds ───────────────────────────────────────────────────────────
    $mod = SUPER

    # Core
    bind = $mod,       Return, exec, ${lib.getExe cfg.terminal}
    bind = $mod,       Q,      killactive
    bind = $mod SHIFT, E,      exit
    bind = $mod,       F,      fullscreen, 0
    bind = $mod SHIFT, F,      togglefloating
    bind = $mod,       P,      pseudo
    bind = $mod,       J,      togglesplit

    # Launcher / utilities
    bind = $mod,       D,      exec, wofi --show drun
    bind = $mod,       E,      exec, thunar
    bind = $mod,       L,      exec, swaylock
    bind = $mod SHIFT, S,      exec, grim -g "$(slurp)" - | wl-copy
    bind = ,           Print,  exec, grim ~/Pictures/screenshot-$(date +%F_%T).png

    # Volume
    bindel = , XF86AudioRaiseVolume,  exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
    bindel = , XF86AudioLowerVolume,  exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindl  = , XF86AudioMute,         exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindl  = , XF86AudioMicMute,      exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

    # Brightness (requires brightnessctl)
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

    # Resize (hold mod + right-click drag also works)
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

  defaultHyprpaperConf = ''
    preload  = ${pkgs.hyprpaper}/share/hyprpaper/no-wallpaper.png
    wallpaper = ,${pkgs.hyprpaper}/share/hyprpaper/no-wallpaper.png
  '';

  defaultWaybarConfig = builtins.toJSON {
    layer = "top";
    position = "top";
    height = 30;
    spacing = 4;
    modules-left = [ "hyprland/workspaces" "hyprland/submap" ];
    modules-center = [ "hyprland/window" ];
    modules-right = [
      "pulseaudio"
      "network"
      "cpu"
      "memory"
      "battery"
      "clock"
      "tray"
    ];
    "hyprland/workspaces" = {
      disable-scroll = true;
      all-outputs = true;
      format = "{icon}";
      format-icons = { default = ""; active = ""; urgent = ""; };
    };
    clock = { format = "  {:%a %d %b  %H:%M}"; tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"; };
    cpu = { format = "  {usage}%"; interval = 5; };
    memory = { format = "  {used:.1f}G"; interval = 5; };
    battery = { states = { warning = 30; critical = 15; }; format = "{icon}  {capacity}%"; format-icons = [ "" "" "" "" "" ]; };
    network = { format-wifi = "  {signalStrength}%"; format-ethernet = " "; format-disconnected = "⚠"; tooltip-format = "{ifname}: {ipaddr}"; };
    pulseaudio = { format = "{icon}  {volume}%"; format-muted = "  muted"; format-icons = { default = [ "" "" "" ]; }; on-click = "pavucontrol"; };
    tray = { spacing = 8; };
  };

  defaultWaybarStyle = ''
    * { border: none; border-radius: 0; font-family: "JetBrainsMono Nerd Font", monospace; font-size: 13px; min-height: 0; }
    window#waybar { background: rgba(26,27,38,0.92); color: #cdd6f4; border-bottom: 2px solid rgba(137,180,250,0.5); }
    #workspaces button { padding: 0 6px; color: #6c7086; }
    #workspaces button.active { color: #89b4fa; border-bottom: 2px solid #89b4fa; }
    #workspaces button.urgent { color: #f38ba8; }
    #clock, #cpu, #memory, #battery, #network, #pulseaudio, #tray { padding: 0 10px; color: #cdd6f4; }
    #battery.warning  { color: #fab387; }
    #battery.critical { color: #f38ba8; }
  '';

  defaultMakoConf = ''
    background-color=#1e1e2e
    text-color=#cdd6f4
    border-color=#89b4fa
    border-radius=8
    border-size=2
    padding=10
    margin=8
    font=JetBrainsMono Nerd Font 11
    width=380
    height=120
    default-timeout=5000
    [urgency=critical]
    border-color=#f38ba8
    default-timeout=0
  '';
in
{
  config = lib.mkIf cfg.enable {

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = "greeter";
      };
    };
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal";
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = false;
    };
    security.rtkit.enable = true;

    security.polkit.enable = true;

    xdg.portal = {
      enable = true;
      wlr.enable = false;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = [ "hyprland" "gtk" ];
    };

    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        nerd-fonts.fira-code
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        liberation_ttf
      ];
      fontconfig.defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };

    hardware.nvidia = lib.mkIf cfg.nvidia {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = false;
      nvidiaSettings = true;
    };
    boot.kernelParams = lib.mkIf cfg.nvidia [ "nvidia-drm.modeset=1" ];

    programs.nm-applet.enable = true;

    programs.thunar = {
      enable = true;
      plugins = with pkgs; [ thunar-archive-plugin thunar-volman ];
    };
    services.gvfs.enable = true;
    services.tumbler.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      MOZ_ENABLE_WAYLAND = "1";
      QT_QPA_PLATFORM = "wayland";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
    };

    environment.systemPackages = with pkgs; [
      cfg.terminal
      waybar
      wofi
      mako
      libnotify
      hyprpaper
      swaylock
      grim
      slurp
      wl-clipboard
      cliphist
      pavucontrol
      wireplumber
      brightnessctl
      adwaita-icon-theme
      gnome-themes-extra
      gtk3
      polkit_gnome
      xdg-utils
      xdg-user-dirs
      playerctl
      imv
      mpv
    ] ++ cfg.extraPackages;

    environment.etc = {
      "xdg/hypr/hyprland.conf".text = defaultHyprlandConf;
      "xdg/hypr/hyprpaper.conf".text = defaultHyprpaperConf;
      "xdg/waybar/config".text = defaultWaybarConfig;
      "xdg/waybar/style.css".text = defaultWaybarStyle;
      "xdg/mako/config".text = defaultMakoConf;
      "xdg/swaylock/config".text = ''
        color=1e1e2e
        ring-color=89b4fa
        inside-color=313244
        text-color=cdd6f4
        line-color=89b4fa
        key-hl-color=cba6f7
        bs-hl-color=f38ba8
        font=JetBrainsMono Nerd Font
        font-size=14
        indicator-radius=80
      '';
      "xdg/gtk-3.0/settings.ini".text = ''
        [Settings]
        gtk-application-prefer-dark-theme=true
        gtk-cursor-theme-name=Adwaita
        gtk-cursor-theme-size=24
        gtk-font-name=Noto Sans 11
        gtk-icon-theme-name=Adwaita
        gtk-theme-name=Adwaita-dark
      '';
    };

    systemd.tmpfiles.rules = [
      "d /home/${cfg.user}/Pictures 0755 ${cfg.user} users -"
    ];

    users.users.${cfg.user}.extraGroups = [ "video" "audio" "input" ];
  };
}
