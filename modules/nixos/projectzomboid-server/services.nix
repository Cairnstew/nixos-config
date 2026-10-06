# modules/nixos/projectzomboid-server/services.nix
# The Project Zomboid dashboard management API, and its registration on the
# reverse-proxy dashboard.
#
# This is host-local wiring, so it lives here rather than upstream: the upstream
# module cannot reference `my.services.proxy` (a standalone flake cannot depend
# on someone's private option namespace — the same reason it exposes
# `webConsoleUpstreams` as plain data instead of a proxy config). It mirrors what
# `modules/nixos/minecraft-server/` does for its own dashboard section.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.project-zomboid-servers;

  # Only enabled servers get a card, and only servers with a console have
  # somewhere to link (webConsole is per-server and defaults to true).
  servers = builtins.attrNames (lib.filterAttrs (_: srv: srv.enable) cfg.servers);

  # The console URL prefix the upstream module emits for its ttyd consoles —
  # `webConsoleUpstreams` gives each server `path = "/pz/<name>/"`.
  consoleBase = "/pz";

  # The API needs the web-console user: the upstream module grants that user a
  # polkit rule for `manage-units` on project-zomboid-* (see its config.nix),
  # which is what authorises start/stop/restart. It also needs `web.enable` for
  # the consoles to exist at all, so the API is gated on both rather than
  # inventing a second privilege path.
  apiEnable = cfg.enable && cfg.web.enable && servers != [ ];

  apiPort = 7798; # loopback; 7799 is the minecraft dashboard API
in
{
  config = lib.mkIf apiEnable {
    systemd.services.project-zomboid-dashboard-api = {
      description = "Project Zomboid dashboard management API";
      after = [ "network.target" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # systemctl must resolve from the unit's PATH; the API shells out to it.
      # No sudo: authorisation is the module's polkit rule, which systemctl
      # consults over D-Bus.
      path = [
        pkgs.systemd
        pkgs.coreutils
      ];

      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${./api.py}";
        User = cfg.web.user;
        Group = cfg.group;
        Environment = [
          "PZ_SERVERS=${lib.concatStringsSep ":" servers}"
          "PZ_CONSOLE_BASE=${consoleBase}"
          "PZ_API_PORT=${toString apiPort}"
        ];
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };

    my.services.proxy.dashboard.projectzomboid = {
      enable = true;
      inherit consoleBase;
      port = apiPort;
    };
  };
}
