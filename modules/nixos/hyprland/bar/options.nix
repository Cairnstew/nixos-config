{ lib, ... }:
let
  customModuleSubmodule = lib.types.submodule {
    options = {
      exec = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "~/.config/waybar/scripts/weather.sh";
        description = "Command to execute for the module output.";
      };
      execIf = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "test -f /sys/class/power_supply/BAT0/capacity";
        description = "Condition that must succeed for exec to run.";
      };
      interval = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.positive);
        default = null;
        example = 60;
        description = "Update interval in seconds. If null, exec runs continuously.";
      };
      format = lib.mkOption {
        type = lib.types.str;
        default = "{}";
        example = "<span color='#89b4fa'>{}</span>";
        description = "Output format string. {} is replaced with exec output.";
      };
      returnType = lib.mkOption {
        type = lib.types.enum [ "json" "text" ];
        default = "text";
        description = "Whether the script returns JSON (for advanced formatting) or plain text.";
      };
      on-click = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "kitty -e htop";
        description = "Command to run on left-click.";
      };
      on-click-right = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "pavucontrol";
        description = "Command to run on right-click.";
      };
      on-click-middle = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Command to run on middle-click.";
      };
      on-scroll-up = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Command to run on scroll up.";
      };
      on-scroll-down = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Command to run on scroll down.";
      };
      tooltip = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable tooltip on hover.";
      };
      tooltip-format = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "{</i>CPU</i>: {usage}%<i>}";
        description = "Tooltip format string.";
      };
      position = lib.mkOption {
        type = lib.types.enum [ "left" "center" "right" ];
        default = "right";
        description = "Which side of the bar the module appears on.";
      };
    };
  };
in
{
  options.my.desktop.hyprland.bar = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable waybar status bar with Hyprland workspace integration.";
    };
    style = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        #custom-bar { background: red; }
      '';
      description = "Extra CSS injected into waybar's style.css on top of the default theme.";
    };
    position = lib.mkOption {
      type = lib.types.enum [ "top" "bottom" ];
      default = "top";
      description = "Waybar position on screen.";
    };
    height = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Waybar height in pixels.";
    };
    customModules = lib.mkOption {
      type = lib.types.attrsOf customModuleSubmodule;
      default = { };
      example = {
        weather = {
          exec = "~/.config/waybar/scripts/weather.sh";
          interval = 600;
          position = "right";
        };
        updates = {
          exec = "~/.config/waybar/scripts/arch-updates.sh";
          interval = 3600;
          format = " <span color='#f5c2e7'>{}</span>";
          on-click = "kitty -e sudo pacman -Syu";
        };
      };
      description = ''
        Custom waybar modules of type custom/<name>. Each attr name becomes the
        module name, e.g. { weather = { ... }; } adds custom/weather.
        The module is automatically inserted into the appropriate modules-*
        list based on its position option.
      '';
    };
    extraModulesLeft = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "custom/weather" ];
      description = "Extra waybar module names appended to modules-left.";
    };
    extraModulesCenter = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "custom/mode" ];
      description = "Extra waybar module names appended to modules-center.";
    };
    extraModulesRight = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "custom/updates" ];
      description = "Extra waybar module names appended to modules-right.";
    };
  };
}
