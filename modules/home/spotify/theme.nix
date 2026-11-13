# Spotify theming — spotatui's `theme` block from the shared palette.
#
# The desktop client and the Waybar now-playing widget are not themeable here:
# Spotify's Electron UI needs a patched client (out of scope for this repo),
# and the widget's colours live in modules/nixos/hyprland/bar (Phase 2).
{ config, lib, ... }:

let
  cfg = config.my.programs.spotify;
  themeLib = import ../../../lib/theme.nix { inherit lib; };

  # spotatui / spotify-tui `theme:` keys.
  mkSettings = p: {
    theme = {
      active = p.accent;
      background = p.background;
      banner = p.accentAlt;
      error = p.error;
      error_border = p.error;
      hint = p.foregroundMuted;
      hovered = p.accent;
      inactive = p.foregroundSubtle;
      playback_bar = p.border;
      playback_progress = p.accent;
      secondary = p.syntaxFunction;
      selected = p.accent;
      header = p.syntaxType;
      highlighted = p.warning;
    };
  };
in
{
  # Declared here, not in options.nix: all theming lives in one file.
  options.my.programs.spotify.theme = themeLib.mkAppTheme {
    base = config.my.theming.colors;
    extraOptions =
      { config }:
      {
        settings = lib.mkOption {
          type = lib.types.attrs;
          readOnly = true;
          default = mkSettings config.palette;
          defaultText = lib.literalExpression "generated from my.theming.colors";
          description = ''
            Generated spotatui config fragment (a `theme:` block). The user's
            `tui.settings` are merged on top when the file is written.
          '';
        };
      };
  };
}
