{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.suwayomi;
in
{
  config = lib.mkMerge [
    # Always create the suwayomi user/group so agenix chown of suwayomi-password
    # succeeds even when the service is disabled on this host.
    (lib.mkIf (cfg.user == "suwayomi") {
      users.users.suwayomi = {
        isSystemUser = true;
        group = cfg.group;
        description = "Suwayomi-Server service user";
        home = cfg.dataDir;
        createHome = true;
      };
    })

    (lib.mkIf (cfg.group == "suwayomi") {
      users.groups.suwayomi = { };
    })

    (lib.mkIf cfg.enable {
      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.settings.server.port ];

      # Serve WebUI under /suwayomi/ subpath. The server injects <base href>
      # into index.html and prefixes API routes. WebUI client (PR #1011) uses
      # relative Vite base paths so dynamic imports resolve against <base>.
      # stripPrefix=false passes the full URI through nginx without stripping.
      my.services.suwayomi.settings.server.webUISubpath = lib.mkDefault "/suwayomi";

      my.services.proxy.upstreams.suwayomi = {
        port = cfg.settings.server.port;
        path = "/suwayomi/";
        stripPrefix = false;  # webUISubpath needs full URI passthrough
        # WebSocket auto-detected by Caddy — GraphQL at /suwayomi/api/graphql works.
      };
    })
  ];
}
