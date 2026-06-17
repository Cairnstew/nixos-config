{ lib, pkgs, ... }:
let
  types = lib.types;
  inherit (types) nullOr;
in
{
  options.my.desktop.hyprland.awww = {
    enable = lib.mkEnableOption "awww animated wallpaper daemon";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.awww;
      defaultText = lib.literalExpression "pkgs.awww";
      description = "The awww wallpaper daemon package (includes both awww-daemon and awww CLI).";
    };

    transition = {
      type = lib.mkOption {
        type = nullOr (types.enum [
          "simple" "center" "outer" "left" "right" "top" "bottom" "wipe" "any" "random"
        ]);
        default = null;
        example = "center";
        description = ''
          Default transition effect when changing wallpapers via `awww img`.
          Set via AWWW_TRANSITION env var. Overridable at runtime with --transition-type.
          'simple' = fade, 'center'/'outer' = grow/shrink, 'left'/'right'/'top'/'bottom' = wipe direction,
          'wipe' = angled wipe, 'any' = random center/outer, 'random' = any effect.
        '';
      };

      step = lib.mkOption {
        type = nullOr (types.ints.between 1 255);
        default = null;
        example = 2;
        description = ''
          Transition smoothness (1–255). Lower = smoother but more GPU work.
          Default: 2 for simple transitions, 90 for geometric transitions.
          Set via AWWW_TRANSITION_STEP env var.
        '';
      };

      fps = lib.mkOption {
        type = nullOr (types.ints.between 1 65535);
        default = null;
        example = 30;
        description = ''
          Transition frame rate (1–65535). Higher = smoother animations.
          Default: 30. Set via AWWW_TRANSITION_FPS env var.
        '';
      };

      angle = lib.mkOption {
        type = nullOr (types.ints.between 0 360);
        default = null;
        example = 30;
        description = ''
          Angle in degrees for the 'wipe' transition effect (0–360).
          Ignored for other transition types.
        '';
      };
    };

    daemonArgs = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "--no-cache" ];
      description = "Extra arguments to pass to awww-daemon.";
    };

    images = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          path = lib.mkOption {
            type = types.path;
            description = "Path to the wallpaper image file.";
          };
          output = lib.mkOption {
            type = nullOr types.str;
            default = null;
            example = "DP-1";
          description = ''
            Monitor output name to set the wallpaper on.
            Set to null (default) to apply to all outputs.
          '';
          };
        };
      });
      default = [ ];
      example = [
        { path = "/run/current-system/sw/share/backgrounds/default.png"; }
        { path = "/path/to/other.png"; output = "DP-1"; }
      ];
      description = ''
        List of images to set at daemon startup via `awww img` commands.
        Each entry can target a specific output or all outputs (output = null).
      '';
    };
  };
}
