# wsl-wm.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.wsl.windowManager;

  launcherScript = pkgs.writeShellScriptBin "start-wm" ''
    set -e
    WM="${cfg.windowManager}"
    DISPLAY_NUM="${cfg.display}"

    echo "Starting $WM via xpra on display $DISPLAY_NUM ..."
    ${pkgs.xpra}/bin/xpra start-desktop "$DISPLAY_NUM" \
      --start-child="$WM" \
      --exit-with-children=yes \
      --daemon=yes \
      --pulseaudio=no \
      --notifications=no \
      --mdns=no \
      --opengl=no \
      ${concatStringsSep " \\\n      " cfg.xpraArgs}

    echo "Attaching..."
    exec ${pkgs.xpra}/bin/xpra attach "$DISPLAY_NUM"
  '';

in {
  options.wsl.windowManager = {
    enable = mkEnableOption "xpra-based window manager on WSL2 via WSLg";

    windowManager = mkOption {
      type = types.str;
      default = "i3";
      description = "The window manager binary to launch inside xpra.";
    };

    display = mkOption {
      type = types.str;
      default = ":1";
      description = "The nested X display number xpra will create.";
    };

    xpraArgs = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra arguments passed to xpra start.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Additional packages to install alongside the window manager.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.xpra
      pkgs.xterm
      launcherScript
    ] ++ cfg.extraPackages;
  };
}