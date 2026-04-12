# wsl-wm.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.wsl.windowManager;
in {
  options.wsl.windowManager = {
    enable = mkEnableOption "Xephyr-based window manager on WSL2 via WSLg";

    windowManager = mkOption {
      type = types.str;
      default = "i3";
      description = "The window manager binary to launch inside Xephyr (e.g. i3, openbox, bspwm).";
    };

    display = mkOption {
      type = types.str;
      default = ":1";
      description = "The nested X display number Xephyr will create.";
    };

    xephyrArgs = mkOption {
      type = types.listOf types.str;
      default = [ "-fullscreen" ];
      description = "Extra arguments passed to Xephyr.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install alongside the window manager.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xorg.xephyr
      xterm          # fallback terminal; useful inside the WM
    ]
    ++ cfg.extraPackages
    # Resolve the WM package by name if it matches a known attr, else expect
    # the user to add it via extraPackages.
    ++ optional (pkgs ? ${cfg.windowManager}) pkgs.${cfg.windowManager};

    # A launcher script available as `start-wm` on PATH
    environment.systemPackages = mkAfter [
      (pkgs.writeShellScriptBin "start-wm" ''
        set -e
        DISPLAY_NUM="${cfg.display}"
        WM="${cfg.windowManager}"
        XEPHYR_ARGS="${concatStringsSep " " cfg.xephyrArgs}"

        echo "Starting Xephyr on display $DISPLAY_NUM ..."
        ${pkgs.xorg.xephyr}/bin/Xephyr "$DISPLAY_NUM" $XEPHYR_ARGS &
        XEPHYR_PID=$!

        # Give Xephyr a moment to initialise
        sleep 1

        echo "Starting $WM on display $DISPLAY_NUM ..."
        DISPLAY="$DISPLAY_NUM" "$WM" &
        WM_PID=$!

        # Clean up Xephyr when the WM exits
        wait "$WM_PID"
        kill "$XEPHYR_PID" 2>/dev/null || true
      '')
    ];
  };
}