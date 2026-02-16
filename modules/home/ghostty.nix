{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.ghostty;
in
{
  options.my.programs.ghostty = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Ghostty terminal emulator";
    };

    enableSystemd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable systemd integration for Ghostty";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ghostty;
      description = "Ghostty package to use (must be provided from flake input)";
      example = lib.literalExpression "inputs.ghostty.packages.\${pkgs.system}.default";
    };

    fontSize = lib.mkOption {
      type = lib.types.int;
      default = 13;
      description = "Font size for Ghostty";
    };

    windowWidth = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Default window width in columns";
    };

    windowHeight = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Default window height in rows";
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Theme name to use";
    };

    gtkTitlebar = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable GTK titlebar (better for tiling window managers)";
    };

    clearDefaultKeybinds = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Clear default keybindings before applying custom ones";
    };

    keybindings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "ctrl+shift+left=new_split:left"
        "ctrl+shift+right=new_split:right"
        "ctrl+shift+down=new_split:down"
        "ctrl+shift+up=new_split:up"
        "ctrl+right=goto_split:right"
        "ctrl+left=goto_split:left"
        "ctrl+down=goto_split:down"
        "ctrl+up=goto_split:up"
        "ctrl+shift+n=new_window"
        "ctrl+shift+w=close_window"
        "ctrl+n=new_tab"
        "ctrl+w=close_surface"
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
        "ctrl+a=select_all"
      ];
      description = "Custom keybindings for Ghostty";
    };

    additionalKeybindings = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional keybindings to append to defaults";
      example = [ "ctrl+shift+t=new_tab" ];
    };

    customThemes = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {
        catppuccin-mocha = {
          background = "1e1e2e";
          cursor-color = "f5e0dc";
          foreground = "cdd6f4";
          palette = [
            "0=#45475a"
            "1=#f38ba8"
            "2=#a6e3a1"
            "3=#f9e2af"
            "4=#89b4fa"
            "5=#f5c2e7"
            "6=#94e2d5"
            "7=#bac2de"
            "8=#585b70"
            "9=#f38ba8"
            "10=#a6e3a1"
            "11=#f9e2af"
            "12=#89b4fa"
            "13=#f5c2e7"
            "14=#94e2d5"
            "15=#a6adc8"
          ];
          selection-background = "353749";
          selection-foreground = "cdd6f4";
        };
      };
      description = "Custom theme definitions";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional Ghostty settings to merge";
      example = { cursor-style = "bar"; };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      systemd.enable = cfg.enableSystemd;
      package = cfg.package;
      settings = {
        gtk-titlebar = cfg.gtkTitlebar;
        font-size = cfg.fontSize;
        window-width = cfg.windowWidth;
        window-height = cfg.windowHeight;
        theme = cfg.theme;
        keybind = cfg.keybindings ++ cfg.additionalKeybindings;
      } // cfg.extraSettings;
      clearDefaultKeybinds = cfg.clearDefaultKeybinds;
      themes = cfg.customThemes;
    };
  };
}