{ lib, pkgs, flake, ... }:

let
  types = lib.types;
  prefs = flake.config.preferences or { };
  defaults = flake.config.defaults or { };
  scheme = flake.config.me.colorScheme or { };
in
{
  options.my.programs.ghostty = {
    enable = lib.mkOption {
      type = types.bool;
      default = (defaults.terminal or "ghostty") == "ghostty";
      description = "Enable Ghostty terminal emulator";
    };

    enableSystemd = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable systemd integration for Ghostty";
    };

    package = lib.mkOption {
      type = types.package;
      default = pkgs.ghostty;
      defaultText = lib.literalExpression "pkgs.ghostty";
      description = "Ghostty package to use (must be provided from flake input)";
      example = lib.literalExpression "inputs.ghostty.packages.\${pkgs.stdenv.hostPlatform.system}.default";
    };

    fontSize = lib.mkOption {
      type = types.int;
      default = prefs.terminalFontSize or 13;
      description = "Font size for Ghostty. Defaults to preferences.terminalFontSize.";
    };

    windowWidth = lib.mkOption {
      type = types.int;
      default = 100;
      description = "Default window width in columns";
    };

    windowHeight = lib.mkOption {
      type = types.int;
      default = 30;
      description = "Default window height in rows";
    };

    theme = lib.mkOption {
      type = types.str;
      default = if scheme ? slug then scheme.slug
        else if (prefs.darkMode or true) then "catppuccin-mocha"
        else "catppuccin-latte";
      description = "Theme name to use. Defaults from me.colorScheme.slug, else preferences.darkMode.";
    };

    gtkTitlebar = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Enable GTK titlebar (better for tiling window managers)";
    };

    clearDefaultKeybinds = lib.mkOption {
      type = types.bool;
      default = true;
      description = "Clear default keybindings before applying custom ones";
    };

    keybindings = lib.mkOption {
      type = types.listOf types.str;
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
        "ctrl+shift+c=copy_to_clipboard"
        "ctrl+shift+v=paste_from_clipboard"
        "ctrl+shift+a=select_all"
      ];
      description = "Custom keybindings for Ghostty";
    };

    additionalKeybindings = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional keybindings to append to defaults";
      example = [ "ctrl+shift+t=new_tab" ];
    };

    customThemes = lib.mkOption {
      type = types.attrsOf types.attrs;
      default = let
        strip = lib.removePrefix "#";
      in if scheme ? base00 then {
        "${scheme.slug}" = {
          background = strip scheme.background;
          cursor-color = strip scheme.cursor;
          foreground = strip scheme.foreground;
          palette = [
            "0=#${strip scheme.base03}"
            "1=#${strip scheme.base08}"
            "2=#${strip scheme.base0B}"
            "3=#${strip scheme.base0A}"
            "4=#${strip scheme.base0D}"
            "5=#${strip scheme.base0E}"
            "6=#${strip scheme.base0C}"
            "7=#${strip scheme.base05}"
            "8=#${strip scheme.base04}"
            "9=#${strip scheme.base08}"
            "10=#${strip scheme.base0B}"
            "11=#${strip scheme.base0A}"
            "12=#${strip scheme.base0D}"
            "13=#${strip scheme.base0E}"
            "14=#${strip scheme.base0C}"
            "15=#${strip scheme.base07}"
          ];
          selection-background = strip scheme.base02;
          selection-foreground = strip scheme.foreground;
        };
      } else {
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
      description = "Custom theme definitions. Defaults derived from me.colorScheme when available.";
    };

    extraSettings = lib.mkOption {
      type = types.attrs;
      default = { };
      description = "Additional Ghostty settings to merge";
      example = { cursor-style = "bar"; };
    };
  };
}
