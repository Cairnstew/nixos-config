{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf filterAttrs;
  cfg = config.my.desktop.hyprland;
  barCfg = cfg.bar;

  hasAmdGpu = config.my.hardware.gpu.mesa.enable;

  amdgpuStats = pkgs.writeShellApplication {
    name = "amdgpu-stats";
    runtimeInputs = [ pkgs.coreutils pkgs.bc ];
    text = ''
      set -euo pipefail

      for card in /sys/class/drm/card*; do
        vendor="$(cat "$card/device/vendor" 2>/dev/null || true)"
        [ "$vendor" != "0x1002" ] && continue

        gpu_busy="$(cat "$card/device/gpu_busy_percent" 2>/dev/null || echo "0")"

        vram_used="$(cat "$card/device/mem_info_vram_used" 2>/dev/null || echo "0")"
        vram_total="$(cat "$card/device/mem_info_vram_total" 2>/dev/null || echo "1")"
        vram_used_g="$(echo "scale=1; $vram_used / 1073741824" | bc)"
        vram_total_g="$(echo "scale=0; $vram_total / 1073741824" | bc)"

        temp=""
        for hw in "$card/device/hwmon/hwmon"*/; do
          if [ -f "''${hw}temp1_input" ]; then
            t="$(cat "''${hw}temp1_input" 2>/dev/null || echo "0")"
            temp="$((t / 1000))"
            break
          fi
        done

        text=" GPU: ''${gpu_busy}%"
        tooltip="GPU: ''${gpu_busy}%"
        tooltip="''${tooltip}\nVRAM: ''${vram_used_g}G / ''${vram_total_g}G"
        [ -n "$temp" ] && tooltip="''${tooltip}\nTemp: ''${temp}°C"

        printf '{"text": "%s", "tooltip": "%s"}\n' "$text" "$tooltip"
        exit 0
      done

      printf '{"text": " GPU: N/A", "tooltip": "No AMD GPU found"}\n'
    '';
  };

  customModNames = builtins.attrNames barCfg.customModules;

  # customModules is attrs (unordered): within a side, render by `order` first,
  # then alphabetically — so related modules (e.g. media buttons) can pin an
  # explicit left-to-right sequence instead of relying on name lexicography.
  orderOf = n: barCfg.customModules.${n}.order;
  sortByOrder = list:
    builtins.sort
      (a: b:
        let oa = orderOf a; ob = orderOf b;
        in if oa != ob then oa < ob else a < b)
      list;

  customLeft = sortByOrder (builtins.filter (n: barCfg.customModules.${n}.position == "left") customModNames);
  customCenter = sortByOrder (builtins.filter (n: barCfg.customModules.${n}.position == "center") customModNames);
  customRight = sortByOrder (builtins.filter (n: barCfg.customModules.${n}.position == "right") customModNames);

  modulesLeft = [ "hyprland/workspaces" "hyprland/submap" ]
    ++ map (n: "custom/${n}") customLeft ++ barCfg.extraModulesLeft;
  modulesCenter = [ "hyprland/window" ]
    ++ map (n: "custom/${n}") customCenter ++ barCfg.extraModulesCenter;
  modulesRight = [
    "pulseaudio"
    "network"
    "cpu"
    "memory"
    "disk"
    "temperature"
    "battery"
    "clock"
    "tray"
  ]
  ++ lib.optionals hasAmdGpu [ "custom/gpu" ]
  ++ map (n: "custom/${n}") customRight ++ barCfg.extraModulesRight;

  amdgpuModuleConfig = lib.optionalAttrs hasAmdGpu {
    "custom/gpu" = {
      exec = "${amdgpuStats}/bin/amdgpu-stats";
      interval = 5;
      return-type = "json";
      tooltip = true;
    };
  };

  # Waybar expects kebab-case keys. The customModule submodule exposes
  # `returnType` (camelCase, matching the other option names); translate it
  # to waybar's `return-type` when serialising. All other submodule keys
  # (exec, interval, format, on-click, tooltip, ...) already match waybar.
  customModuleConfig = name:
    let
      raw = barCfg.customModules.${name};
    in
    filterAttrs (n: v: v != null)
      (builtins.removeAttrs raw [ "position" "returnType" ]
        // { return-type = raw.returnType; });

  customModulesConfig = builtins.listToAttrs (map
    (n: {
      name = "custom/${n}";
      value = customModuleConfig n;
    })
    customModNames);

  waybarConfigJSON = builtins.toJSON (rec {
    layer = "top";
    position = barCfg.position;
    height = barCfg.height;
    spacing = 4;

    "modules-left" = modulesLeft;
    "modules-center" = modulesCenter;
    "modules-right" = modulesRight;

    "hyprland/workspaces" = {
      disable-scroll = true;
      all-outputs = true;
      format = "{icon}";
      format-icons = {
        default = "●";
        active = "○";
        urgent = "!";
      };
    };

    clock = {
      format = "  {:%a %d %b  %H:%M}";
      tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
    };

    cpu = {
      format = " {usage}%";
      interval = 5;
      tooltip = true;
      tooltip-format = "CPU: {usage}%  Load: {load}  Freq: {avgFrequency}GHz";
    };

    memory = {
      format = " {used:.1f}G";
      interval = 5;
      tooltip = true;
      tooltip-format = "RAM: {used:.1f}G / {total:.1f}G ({percentage}%)";
    };

    disk = {
      format = " {used}";
      interval = 60;
      tooltip = true;
      tooltip-format = "Disk: {used} / {total} ({percentage_used}%)";
      paths = [ "/" ];
    };

    temperature = {
      format = " {temperatureC}°C";
      interval = 5;
      tooltip = true;
      tooltip-format = "CPU: {temperatureC}°C";
      thermal-zone = 0;
    };

    battery = {
      # waybar ≥ 0.11 rewrote the battery module. Unknown format args (e.g. the
      # removed `{timeToFull}`) make fmt::format throw inside update() BEFORE
      # label_.set_markup() runs, so the module renders nothing while the
      # journal spams "battery: argument not found". Use only documented args:
      # {capacity} {power} {icon} {time} {timeTo} {cycles} {health}.
      interval = 60;
      states = {
        warning = 30;
        critical = 15;
      };
      format = "{icon} {capacity}%";
      # Status-aware icons: object keys are matched against the sysfs status
      # (discharging → default; charging → bolt + battery; plugged/full → full).
      format-icons = {
        default = [ "" "" "" "" "" ];
        charging = [ "" "" "" "" "" ];
        full = "";
        plugged = "";
      };
      tooltip = true;
      tooltip-format = ''Battery: {capacity}%  {power}W
{timeTo}'';
      # Left-click lock, right-click suspend (deliberate), scroll = backlight.
      on-click = "loginctl lock-session";
      on-click-right = "systemctl suspend";
      on-scroll-up = "brightnessctl set 5%+";
      on-scroll-down = "brightnessctl set 5%-";
      # Native low-battery events (waybar ≥ 0.15, fire once per state change).
      events = {
        on-discharging-warning =
          "notify-send -u normal -a waybar 'Low battery' 'Battery below 30% — plug in soon'";
        on-discharging-critical =
          "notify-send -u critical -a waybar 'Critical battery' 'Battery below 15% — suspend soon'";
      };
      # Smooth the power reading so the {timeTo} estimate doesn't jump around.
      smooth-power = true;
    };

    network = {
      format-wifi = " {signalStrength}%";
      format-ethernet = " {ipaddr}/{cidr}";
      format-disconnected = "  disconnected";
      tooltip-format = "{ifname}: {ipaddr}/{cidr}  ({essid})";
      interval = 5;
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-muted = "  muted";
      format-icons = { default = [ "" "" "" ]; };
      on-click = "pavucontrol";
      tooltip = true;
      tooltip-format = "Volume: {volume}%  ({desc})";
    };

    tray = { spacing = 8; };
  } // amdgpuModuleConfig // customModulesConfig);

  customModuleCSS = lib.concatStringsSep "\n" (map
    (name: ''
      #custom-${name} {
        padding: 0 10px;
      }
    '')
    customModNames);

  defaultWaybarStyle = ''
    * {
      border: none;
      border-radius: 0;
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background: rgba(26,27,38,0.92);
      color: #cdd6f4;
      border-bottom: 2px solid rgba(137,180,250,0.5);
    }

    #workspaces button {
      padding: 0 6px;
      color: #6c7086;
    }
    #workspaces button.active {
      color: #89b4fa;
      border-bottom: 2px solid #89b4fa;
    }
    #workspaces button.urgent {
      color: #f38ba8;
    }

    #custom-submap {
      padding: 0 8px;
      color: #a6e3a1;
    }

    #window {
      padding: 0 10px;
      color: #cdd6f4;
    }

    #pulseaudio { padding: 0 10px; color: #cdd6f4; }
    #network     { padding: 0 10px; color: #cdd6f4; }
    #cpu         { padding: 0 10px; color: #89b4fa; }
    #memory      { padding: 0 10px; color: #a6e3a1; }
    #disk        { padding: 0 10px; color: #f5c2e7; }
    #temperature { padding: 0 10px; color: #fab387; }
    #custom-gpu  { padding: 0 10px; color: #94e2d5; }
    #clock       { padding: 0 10px; color: #cdd6f4; }
    #battery     { padding: 0 10px; color: #cdd6f4; }
    #tray        { padding: 0 10px; }

    #battery.warning  { color: #fab387; }
    #battery.critical { color: #f38ba8; }
    #battery.charging { color: #a6e3a1; }
    #battery.plugged  { color: #a6e3a1; }
    #battery.full     { color: #a6e3a1; }
    #temperature.critical { color: #f38ba8; }

    #pulseaudio.muted { color: #6c7086; }
    #network.disconnected { color: #f38ba8; }

    #custom-spotify-now-playing { padding: 0 10px; color: #1db954; }
    #custom-spotify-now-playing.playing { color: #1db954; }
    #custom-spotify-now-playing.paused { color: #6c7086; }
    #custom-spotify-now-playing.idle { color: #6c7086; }
    /* Inline media-control buttons (left of the song info) — one visual cluster. */
    #custom-spotify-back, #custom-spotify-play, #custom-spotify-forward {
      padding: 0 6px;
      color: #cdd6f4;
    }
    #custom-spotify-back:hover, #custom-spotify-play:hover, #custom-spotify-forward:hover {
      color: #1db954;
    }

    /* Upvote button */
    #custom-spotify-upvote { padding: 0 6px; color: #6c7086; }
    #custom-spotify-upvote.not-upvoted { color: #6c7086; }
    #custom-spotify-upvote.upvoted { color: #f38ba8; }
    #custom-spotify-upvote:hover { color: #f38ba8; }

    ${customModuleCSS}

    tooltip {
      background: rgba(26,27,38,0.95);
      border: 1px solid rgba(137,180,250,0.5);
      border-radius: 6px;
    }
    tooltip label {
      padding: 6px 10px;
    }

    /* Waybar popup menu (widget control panes, e.g. custom module `menu`).
       Themed to match the bar; nerd font so glyph item labels render. */
    menu {
      background: rgba(26,27,38,0.97);
      border: 1px solid rgba(137,180,250,0.5);
      border-radius: 6px;
      padding: 4px;
      font-family: "JetBrainsMono Nerd Font", monospace;
    }
    menuitem {
      border-radius: 4px;
      color: #cdd6f4;
      padding: 3px 12px;
    }
    menuitem:hover {
      background: rgba(137,180,250,0.18);
      color: #89b4fa;
    }
    ${barCfg.style}
  '';
in
{
  config = lib.mkMerge [
    (mkIf (cfg.enable && barCfg.enable) {
      environment.systemPackages = with pkgs; [ waybar ];

      environment.etc = {
        "xdg/waybar/config".text = waybarConfigJSON;
        "xdg/waybar/style.css".text = defaultWaybarStyle;
      } // lib.mapAttrs' (name: text: lib.nameValuePair "xdg/waybar/${name}" { inherit text; }) barCfg.menuFiles;
    })
    (mkIf (cfg.enable && barCfg.enable && hasAmdGpu) {
      environment.systemPackages = [ amdgpuStats ];
    })

    (mkIf (cfg.enable && barCfg.enable) {
      systemd.user.services.waybar = {
        description = "Waybar status bar";
        documentation = [ "https://github.com/Alexays/Waybar" ];
        partOf = [ "hyprland-session.target" ];
        after = [ "hyprland-session.target" ];
        wantedBy = [ "hyprland-session.target" ];
        # Restart on `nixos-rebuild switch` when the generated config/style
        # actually changed. NixOS's switch-to-configuration runs a per-user pass
        # and restarts NixOS-declared user units whose restartTriggers differ
        # (units shadowed by ~/.config/systemd/user are skipped, so this stays
        # under /etc/systemd/user). Hash of the generated files keeps the unit
        # small and unchanged rebuilds don't restart (same hash).
        restartTriggers = [
          (builtins.hashString "sha256"
            (waybarConfigJSON + defaultWaybarStyle + builtins.toJSON barCfg.menuFiles))
        ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.waybar}/bin/waybar";
          Restart = "on-failure";
          RestartSec = "2";
        };
      };
    })
  ];
}
