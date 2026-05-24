{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.my.services.wsl-wm;

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
in
{
  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.xpra
      pkgs.xterm
      launcherScript
    ] ++ cfg.extraPackages;
  };
}
