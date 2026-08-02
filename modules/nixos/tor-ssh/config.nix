{ config, lib, ... }:
let
  cfg = config.my.services.torSsh;
  inherit (lib) mkIf optionalAttrs;
in
{
  config = mkIf cfg.enable {
    services.tor = {
      enable = true;
      openFirewall = cfg.openFirewall;

      # onionServices are rendered regardless of relay.enable — no relay needed.
      relay.onionServices.${cfg.serviceName} = {
        version = 3;
        map = [
          {
            port = cfg.onionPort;
            target = {
              addr = "127.0.0.1";
              port = cfg.localPort;
            };
          }
        ];
      }
      // optionalAttrs (cfg.secretKey != null) { secretKey = cfg.secretKey; }
      // optionalAttrs (cfg.authorizedClients != [ ]) { inherit (cfg) authorizedClients; };
    };
  };
}
