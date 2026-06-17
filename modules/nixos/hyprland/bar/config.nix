{ config, lib, pkgs, ... }:
let
  cfg = config.my.desktop.hyprland;
  barCfg = cfg.bar;

  defaultWaybarConfig = builtins.toJSON {
    layer = "top";
    position = barCfg.position;
    height = barCfg.height;
    spacing = 4;

    modules-left = [ "hyprland/workspaces" "hyprland/submap" ];
    modules-center = [ "hyprland/window" ];
    modules-right = [
      "pulseaudio"
      "network"
      "cpu"
      "memory"
      "disk"
      "temperature"
      "battery"
      "clock"
      "tray"
    ];

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
      format-icons = {
        default = [ "" "" "" ];
      };
      on-click = "pavucontrol";
      tooltip = true;
      tooltip-format = "Volume: {volume}%  ({desc})";
    };

    tray = { spacing = 8; };
  };

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
    #clock       { padding: 0 10px; color: #cdd6f4; }
    #battery     { padding: 0 10px; color: #cdd6f4; }
    #tray        { padding: 0 10px; }

    #battery.warning  { color: #fab387; }
    #battery.critical { color: #f38ba8; }
    #temperature.critical { color: #f38ba8; }

    #pulseaudio.muted { color: #6c7086; }
    #network.disconnected { color: #f38ba8; }

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
  config = lib.mkIf (cfg.enable && barCfg.enable) {
    environment.systemPackages = with pkgs; [ waybar ];

    environment.etc = {
      "xdg/waybar/config".text = defaultWaybarConfig;
      "xdg/waybar/style.css".text = defaultWaybarStyle;
    };
  };
}
