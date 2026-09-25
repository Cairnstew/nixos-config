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
      menu = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "on-click-right";
        description = ''
          Event that pops up an interactable GtkMenu pane for this module
          (waybar's only multi-button UI — label HTML cannot dispatch clicks to
          separate elements). Value is the triggering event, e.g. "on-click" or
          "on-click-right". Requires menu-file + menu-actions.
        '';
      };
      menu-file = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/etc/xdg/waybar/spotify-menu.xml";
        description = "Path to a GtkBuilder XML file containing a GtkMenu with id 'menu' (see menuFiles — keep it under /etc/xdg/waybar, not ~/.config).";
      };
      menu-actions = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        example = { shutdown = "systemctl poweroff"; };
        description = "Map of GtkMenuItem ids (in menu-file) to commands — each item is a button.";
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
      order = lib.mkOption {
        type = lib.types.int;
        default = 0;
        example = 1;
        description = ''
          Display order within the module's side. customModules render sorted
          alphabetically by name; set order to control the sequence explicitly
          (lower first, ties broken alphabetically). Use adjacent values for
          related modules that must keep a fixed left-to-right order.
        '';
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
    menuFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = { };
      example."power-menu" = ''
        <?xml version="1.0" encoding="UTF-8"?>
        <interface>…GtkMenu id="menu"…</interface>
      '';
      description = ''
        GtkBuilder menu files for custom-module popup menus, written to
        /etc/xdg/waybar/<name>. Keep menu files here (system path), NOT in
        ~/.config/waybar via home-manager: NixOS restarts user units with
        changed restartTriggers BEFORE the home-manager user activation runs,
        and waybar builds its popup menu once at startup — a home-manager
        file doesn't exist yet and the menu is silently disabled.
      '';
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
