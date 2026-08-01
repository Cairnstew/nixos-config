{ config, lib, ... }:
let
  cfg = config.my.services.ttyd;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    services.ttyd = {
      enable = true;
      inherit (cfg) port;
      interface = cfg.address;
      username = cfg.username;
      passwordFile = cfg.passwordFile;
      writeable = cfg.writeable;
      entrypoint = cfg.entrypoint;
      maxClients = cfg.maxClients;
      checkOrigin = cfg.checkOrigin;
    }
    // lib.optionalAttrs (cfg.user != null) { user = cfg.user; };

    # If bound to a fallback-mesh IP that isn't up yet (e.g. ZeroTier assigns
    # its address after boot), the initial bind fails — retry until it lands.
    systemd.services.ttyd.serviceConfig.Restart = "on-failure";

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    my.services.proxy.upstreams.ttyd = lib.mkIf cfg.proxyUpstream {
      port = cfg.port;
      path = "/ttyd/";
      stripPrefix = true; # ttyd serves its UI at / — strip /ttyd/ so index + /ws resolve
    };
  };
}
