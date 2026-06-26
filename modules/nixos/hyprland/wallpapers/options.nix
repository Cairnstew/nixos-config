{ lib, pkgs, ... }:
let
  types = lib.types;
  inherit (types) nullOr;
in
{
  options.my.desktop.hyprland.wallpapers = {
    enable = lib.mkEnableOption "unified wallpaper management (hyprpaper, awww, or mpvpaper)";

    backend = lib.mkOption {
      type = types.enum [ "hyprpaper" "awww" "mpvpaper" "waypaper" "swaybg" ];
      default = "hyprpaper";
      example = "awww";
      description = ''
        Which wallpaper daemon to use:
        - hyprpaper: lightweight static image wallpaper daemon
        - awww: animated wallpaper daemon with transition effects
        - mpvpaper: video wallpaper program using mpv
        - waypaper: GUI wallpaper setter frontend (selects backend internally)
        - swaybg: minimal static image wallpaper daemon (recommended)
      '';
    };

    images = lib.mkOption {
      type = types.listOf (types.submodule {
        options = {
          path = lib.mkOption {
            type = types.path;
            description = "Path to the wallpaper image/video file.";
          };
          output = lib.mkOption {
            type = nullOr types.str;
            default = null;
            example = "DP-1";
            description = ''
              Output name to set the wallpaper on.
              null = apply to all outputs (except mpvpaper, where ALL is used).
            '';
          };
        };
      });
      default = [ ];
      example = [
        { path = "/run/current-system/sw/share/backgrounds/default.png"; }
        { path = "/path/to/video.mp4"; output = "DP-1"; }
      ];
      description = ''
        List of wallpapers to set at startup. Each entry has a path and optional output target.
        For hyprpaper: all images are preloaded and the first image is set on all outputs.
        For awww: images are set via awww img commands at daemon startup.
        For mpvpaper: images (videos) are played via mpvpaper instances.
      '';
    };

    wallpaperDir = lib.mkOption {
      type = types.path;
      default = ./wallpapers;
      defaultText = lib.literalExpression "./wallpapers";
      description = ''
        Directory containing wallpaper image/video files for this module.
        Drop wallpaper files here and reference them in `images` via
        `''${config.my.desktop.hyprland.wallpapers.wallpaperDir}/filename.png`.
        For Waypaper backend, this is used as the default wallpaper folder.
      '';
    };

    span = {
      enable = lib.mkEnableOption ''
        multi-monitor spanning: crop a single source image/video into per-output
        segments so it appears as one continuous canvas across all monitors
      '';

      source = lib.mkOption {
        type = types.path;
        example = ./wallpapers/span-source.mp4;
        description = ''
          Source image or video file to span across all monitors.
          Auto-scaled and cropped to fill the combined monitor canvas based on `fit` mode.
        '';
      };

      fit = lib.mkOption {
        type = types.enum [ "cover" "contain" "stretch" ];
        default = "cover";
        description = ''
          How to fit the source onto the combined monitor canvas:
          - cover:   scale to fill the entire canvas (may crop edges)
          - contain: scale to fit within the canvas (may add black bars)
          - stretch: distort to exactly match the canvas dimensions
        '';
      };

      segments = lib.mkOption {
        type = types.listOf (types.submodule {
          options = {
            output = lib.mkOption {
              type = types.str;
              example = "DP-1";
              description = "Output name to assign this cropped segment to.";
            };
            x = lib.mkOption {
              type = types.int;
              description = "X offset in the source to start cropping from.";
            };
            y = lib.mkOption {
              type = types.int;
              description = "Y offset in the source to start cropping from.";
            };
            w = lib.mkOption {
              type = types.int;
              description = "Width of the crop region in the source.";
            };
            h = lib.mkOption {
              type = types.int;
              description = "Height of the crop region in the source.";
            };
            rotate = lib.mkOption {
              type = types.int;
              default = 0;
              description = "Rotation to apply to the cropped segment: 0, 90, 180, or 270.";
            };
          };
        });
        default = [ ];
        example = [
          { output = "DP-3"; x = 0; y = 0; w = 1200; h = 1920; rotate = 90; }
          { output = "DP-1"; x = 1200; y = 240; w = 2560; h = 1440; }
          { output = "DP-2"; x = 3760; y = 0; w = 1200; h = 1920; rotate = 270; }
        ];
        description = ''
          Per-output crop segments. When empty (default), auto-derived from my.monitors
          with the selected fit mode. Set explicitly for full manual control.
        '';
      };
    };

    settings = {
      awww = {
        transitionType = lib.mkOption {
          type = nullOr (types.enum [
            "simple"
            "center"
            "outer"
            "left"
            "right"
            "top"
            "bottom"
            "wipe"
            "any"
            "random"
          ]);
          default = null;
          example = "center";
          description = ''
            Default transition effect. Overridable at runtime via --transition-type.
          '';
        };

        transitionStep = lib.mkOption {
          type = nullOr (types.ints.between 1 255);
          default = null;
          example = 2;
          description = "Transition smoothness (1–255). Lower = smoother.";
        };

        transitionFps = lib.mkOption {
          type = nullOr (types.ints.between 1 65535);
          default = null;
          example = 30;
          description = "Transition frame rate (1–65535).";
        };

        transitionAngle = lib.mkOption {
          type = nullOr (types.ints.between 0 360);
          default = null;
          example = 30;
          description = "Angle for the 'wipe' transition effect (0–360).";
        };

        daemonArgs = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "--no-cache" ];
          description = "Extra arguments to pass to awww-daemon.";
        };
      };

      mpvpaper = {
        mpvOptions = lib.mkOption {
          type = types.str;
          default = "no-audio --loop-file=inf --no-osc --no-osd-bar --no-input-default-bindings --no-window-dragging";
          example = "no-audio --loop-playlist shuffle";
          description = "mpv options passed to mpvpaper via -o.";
        };

        ipcSocket = lib.mkOption {
          type = nullOr types.str;
          default = null;
          example = "/tmp/mpvpaper.sock";
          description = ''
            Path to mpv input-ipc-server socket for runtime control.
            If set, mpvpaper instances will listen on this socket (appended with output name).
          '';
        };
      };

      waypaper = {
        backend = lib.mkOption {
          type = types.enum [ "swaybg" "hyprpaper" "awww" "swww" "mpvpaper" "gslapper" "wallutils" "feh" "xwallpaper" ];
          default = "swaybg";
          example = "hyprpaper";
          description = ''
            Internal wallpaper backend that Waypaper will use.
            The corresponding package is installed automatically for backends
            available in nixpkgs (swaybg, hyprpaper, awww, mpvpaper, wallutils, feh, xwallpaper).
            For swww or gslapper, add the package via extraPackages.
          '';
        };

        folder = lib.mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "/home/user/Wallpapers";
          description = ''
            Default wallpaper folder shown in the Waypaper GUI.
            Falls back to the module's wallpaperDir when null.
          '';
        };

        fillOption = lib.mkOption {
          type = types.enum [ "cover" "fill" "fit" "center" "stretch" "tile" ];
          default = "cover";
          description = "How the wallpaper is fit to the screen.";
        };

        extraPackages = lib.mkOption {
          type = types.listOf types.package;
          default = [ ];
          example = [ pkgs.swww ];
          description = "Additional packages needed by the selected Waypaper backend (e.g., swww, gslapper).";
        };
      };
    };
  };
}
