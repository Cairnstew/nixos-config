{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.remoteGui;
  inherit (lib) mkIf mkMerge mapAttrsToList escapeShellArg;
in
{
  config = mkIf cfg.enable {
    systemd.services = mkMerge (
      [
        # ── Xvfb virtual framebuffer ─────────────────────────────────────────
        # -nolisten tcp: only the local Unix socket, so only processes on this
        # host can connect; -ac: no X auth (fed by local apps + x11vnc only).
        {
          remote-gui-xvfb = {
            description = "Xvfb virtual framebuffer for remote GUI apps";
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              ExecStart = "${pkgs.xvfb}/bin/Xvfb ${cfg.display} -screen 0 ${cfg.screen} -nolisten tcp -ac";
              Restart = "on-failure";
            };
          };
        }

        # ── x11vnc: share the virtual display over TCP ─────────────────────
        (mkIf cfg.vnc.enable {
          remote-gui-x11vnc = {
            description = "x11vnc server exposing the virtual display";
            wantedBy = [ "multi-user.target" ];
            after = [ "remote-gui-xvfb.service" ];
            requires = [ "remote-gui-xvfb.service" ];
            serviceConfig = {
              ExecStart = "${pkgs.x11vnc}/bin/x11vnc -display ${cfg.display} -rfbport ${toString cfg.vnc.port} -forever -shared -listen ${cfg.vnc.listenAddress} ${if cfg.vnc.passwordFile != null then "-passwdfile ${cfg.vnc.passwordFile}" else "-nopw"}";
              Restart = "on-failure";
            };
          };
        })

        # ── Optional window manager for the virtual display ─────────────────
        (mkIf (cfg.windowManager != null) {
          remote-gui-wm = {
            description = "Window manager on the virtual display";
            wantedBy = [ "multi-user.target" ];
            after = [ "remote-gui-xvfb.service" ];
            requires = [ "remote-gui-xvfb.service" ];
            serviceConfig = {
              Environment = [ "DISPLAY=${cfg.display}" ];
              ExecStart = "${lib.getExe' cfg.windowManager (lib.getName cfg.windowManager)}";
              Restart = "on-failure";
            };
          };
        })
      ]
      # ── Per-app units ──────────────────────────────────────────────────────
      ++ mapAttrsToList
        (name: app: {
          "remote-gui-app-${name}" = {
            description = "Remote GUI app: ${name}";
            after = [ "remote-gui-xvfb.service" ];
            requires = [ "remote-gui-xvfb.service" ];
            wantedBy = mkIf app.autostart [ "multi-user.target" ];
            serviceConfig = {
              User = app.user;
              Environment = [ "DISPLAY=${cfg.display}" ] ++ mapAttrsToList (k: v: "${k}=${v}") app.extraEnv;
              ExecStart = "${pkgs.bash}/bin/bash -c ${escapeShellArg app.command}";
              Restart = if app.restart then "on-failure" else "no";
              RestartSec = "5s";
            };
          };
        })
        cfg.apps
    );
  };
}
