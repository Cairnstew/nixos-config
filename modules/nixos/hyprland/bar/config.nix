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

  customLeft   = builtins.filter (n: barCfg.customModules.${n}.position == "left")   customModNames;
  customCenter = builtins.filter (n: barCfg.customModules.${n}.position == "center") customModNames;
  customRight  = builtins.filter (n: barCfg.customModules.${n}.position == "right")  customModNames;

  modulesLeft   = [ "hyprland/workspaces" "hyprland/submap" ]
    ++ map (n: "custom/${n}") customLeft   ++ barCfg.extraModulesLeft;
  modulesCenter = [ "hyprland/window" ]
    ++ map (n: "custom/${n}") customCenter ++ barCfg.extraModulesCenter;
  modulesRight  = [
    "pulseaudio" "network" "cpu" "memory" "disk"
    "temperature" "battery" "clock" "tray"
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

  customModuleConfig = name:
    filterAttrs (n: v: v != null)
      (builtins.removeAttrs barCfg.customModules.${name} [ "position" ]);

  customModulesConfig = builtins.listToAttrs (map (n: {
    name = "custom/${n}";
    value = customModuleConfig n;
  }) customModNames);

  waybarConfigJSON = builtins.toJSON (rec {
    layer = "top";
    position = barCfg.position;
    height = barCfg.height;
    spacing = 4;

    "modules-left"   = modulesLeft;
    "modules-center" = modulesCenter;
    "modules-right"  = modulesRight;

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
      format = " {used:.1f}G";
      interval = 60;
      tooltip = true;
      tooltip-format = "Disk: {used:.1f}G / {total:.1f}G ({percentage}%)";
      path = "/";
    };

    temperature = {
      format = " {temperatureC}°C";
      interval = 5;
      tooltip = true;
      tooltip-format = "CPU: {temperatureC}°C";
      thermal-zone = 0;
    };

    battery = {
      states = { warning = 30; critical = 15; };
      format = "{icon} {capacity}%";
      format-icons = [ "" "" "" "" "" ];
      tooltip = true;
      tooltip-format = "Battery: {capacity}%  {power}W  ({timeTo}, {timeToFull})";
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

  customModuleCSS = lib.concatStringsSep "\n" (map (name: ''
    #custom-${name} {
      padding: 0 10px;
    }
  '') customModNames);

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
    #temperature.critical { color: #f38ba8; }

    #pulseaudio.muted { color: #6c7086; }
    #network.disconnected { color: #f38ba8; }

    ${customModuleCSS}

    tooltip {
      background: rgba(26,27,38,0.95);
      border: 1px solid rgba(137,180,250,0.5);
      border-radius: 6px;
    }
    tooltip label {
      padding: 6px 10px;
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
      };
    })
    (mkIf (cfg.enable && barCfg.enable && hasAmdGpu) {
      environment.systemPackages = [ amdgpuStats ];
    })
  ];
}
