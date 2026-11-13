# Waybar theming — generates the whole `style.css` from the shared palette.
#
# Before this file the stylesheet was ~110 lines of literal Catppuccin hexes
# embedded in config.nix (and a Tokyo-Night `#1a1b26` bar background that did
# not match the rest of the palette). Waybar is GTK3 CSS: `rgba(r, g, b, a)` is
# the portable translucent form, so every alpha colour goes through
# `color.toCssRgba`.
{ config, lib, ... }:

let
  barCfg = config.my.desktop.hyprland.bar;
  themeLib = import ../../../../lib/theme.nix { inherit lib; };
  t = barCfg.theme;
  p = t.palette;
  color = themeLib.color;

  # `rgb()` with an explicit alpha, for translucent surfaces.
  rgba = hex: opacity: color.toCssRgba (color.alpha hex opacity);

  # Spotify's brand green. Deliberately fixed: it identifies the service, it is
  # not part of any palette, and the old stylesheet hardcoded it too.
  spotify = "#1db954";

  # One `#custom-<name> { padding: 0 10px; }` rule per configured module.
  customModuleCSS = lib.concatStringsSep "\n" (
    map
      (name: ''
        #custom-${name} {
          padding: 0 10px;
        }
      '')
      (builtins.attrNames barCfg.customModules)
  );

  generated = ''
    * {
      border: none;
      border-radius: 0;
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px;
      min-height: 0;
    }

    window#waybar {
      background: ${rgba p.background t.backgroundOpacity};
      color: ${p.foreground};
      border-bottom: 2px solid ${rgba p.accent t.borderOpacity};
    }

    #workspaces button {
      padding: 0 6px;
      color: ${p.foregroundMuted};
    }
    #workspaces button.active {
      color: ${p.accent};
      border-bottom: 2px solid ${p.accent};
    }
    #workspaces button.urgent {
      color: ${p.error};
    }

    #custom-submap {
      padding: 0 8px;
      color: ${p.success};
    }

    #window {
      padding: 0 10px;
      color: ${p.foreground};
    }

    #pulseaudio { padding: 0 10px; color: ${p.foreground}; }
    #network     { padding: 0 10px; color: ${p.foreground}; }
    #cpu         { padding: 0 10px; color: ${p.accent}; }
    #memory      { padding: 0 10px; color: ${p.success}; }
    #disk        { padding: 0 10px; color: ${p.terminal.magenta}; }
    #temperature { padding: 0 10px; color: ${p.warning}; }
    #custom-gpu  { padding: 0 10px; color: ${p.terminal.cyan}; }
    #clock       { padding: 0 10px; color: ${p.foreground}; }
    #battery     { padding: 0 10px; color: ${p.foreground}; }
    #tray        { padding: 0 10px; }

    #battery.warning  { color: ${p.warning}; }
    #battery.critical { color: ${p.error}; }
    #battery.charging { color: ${p.success}; }
    #battery.plugged  { color: ${p.success}; }
    #battery.full     { color: ${p.success}; }
    #temperature.critical { color: ${p.error}; }

    #pulseaudio.muted { color: ${p.foregroundMuted}; }
    #network.disconnected { color: ${p.error}; }

    #custom-spotify-now-playing { padding: 0 10px; color: ${spotify}; }
    #custom-spotify-now-playing.playing { color: ${spotify}; }
    #custom-spotify-now-playing.paused { color: ${p.foregroundMuted}; }
    #custom-spotify-now-playing.idle { color: ${p.foregroundMuted}; }

    /* OpenCode general-provider token indicator (OC1 / OC2). The text colour
       comes from an inline <span> in the JSON (blue = token 1, green = token 2,
       red = key matches neither), so only the chrome is styled here. */
    #custom-opencode-key {
      padding: 0 8px;
      border-radius: 4px;
      color: ${p.foreground};
    }
    #custom-opencode-key:hover {
      background: ${rgba p.accent t.hoverOpacity};
    }
    /* Inline media-control buttons (left of the song info) — one visual cluster. */
    #custom-spotify-back, #custom-spotify-play, #custom-spotify-forward {
      padding: 0 6px;
      color: ${p.foreground};
    }
    #custom-spotify-back:hover, #custom-spotify-play:hover, #custom-spotify-forward:hover {
      color: ${spotify};
    }

    /* Upvote button */
    #custom-spotify-upvote { padding: 0 6px; color: ${p.foregroundMuted}; }
    #custom-spotify-upvote.not-upvoted { color: ${p.foregroundMuted}; }
    #custom-spotify-upvote.upvoted { color: ${p.error}; }
    #custom-spotify-upvote:hover { color: ${p.error}; }

    ${customModuleCSS}

    tooltip {
      background: ${rgba p.background t.popupOpacity};
      border: 1px solid ${rgba p.accent t.borderOpacity};
      border-radius: 6px;
    }
    tooltip label {
      padding: 6px 10px;
    }

    /* Waybar popup menu (widget control panes, e.g. custom module `menu`).
       Themed to match the bar; nerd font so glyph item labels render. */
    menu {
      background: ${rgba p.background t.popupOpacity};
      border: 1px solid ${rgba p.accent t.borderOpacity};
      border-radius: 6px;
      padding: 4px;
      font-family: "JetBrainsMono Nerd Font", monospace;
    }
    menuitem {
      border-radius: 4px;
      color: ${p.foreground};
      padding: 3px 12px;
    }
    menuitem:hover {
      background: ${rgba p.accent t.hoverOpacity};
      color: ${p.accent};
    }
  '';
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.desktop.hyprland.bar.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        backgroundOpacity = lib.mkOption {
          type = lib.types.float;
          default = 0.92;
          description = "Opacity of the bar background (0.0-1.0).";
        };

        borderOpacity = lib.mkOption {
          type = lib.types.float;
          default = 0.5;
          description = "Opacity of the accent border/tooltip outline (0.0-1.0).";
        };

        hoverOpacity = lib.mkOption {
          type = lib.types.float;
          default = 0.18;
          description = "Opacity of the accent wash behind hovered items (0.0-1.0).";
        };

        popupOpacity = lib.mkOption {
          type = lib.types.float;
          default = 0.97;
          description = "Opacity of tooltips and popup menus (0.0-1.0).";
        };

        style = lib.mkOption {
          type = lib.types.lines;
          readOnly = true;
          default = if config.enable then generated else "";
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = ''
            The generated `style.css`. config.nix appends `bar.style` (user
            overrides) after it.
          '';
        };
      };
  };
}
