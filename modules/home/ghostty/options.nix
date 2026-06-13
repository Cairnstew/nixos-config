{ lib, pkgs, flake, ... }:

let
  types = lib.types;
  prefs = flake.config.preferences or { };
  defaults = flake.config.defaults or { };
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
      type = types.nullOr types.str;
      default = null;
      description = "Theme name to use. Null lets Stylix (or Ghostty built-in) handle colors.";
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
      default = { };
      description = "Custom theme definitions. Empty by default — Stylix handles theming when enabled.";
    };

    extraSettings = lib.mkOption {
      type = types.attrs;
      default = { };
      description = "Additional Ghostty settings to merge";
      example = { cursor-style = "bar"; };
    };
  };
}
