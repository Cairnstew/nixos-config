{ lib, config, pkgs, ... }:
let
  cfg = config.my.services.rustdesk;
in
{
  options.my.services.rustdesk = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Enable RustDesk self-hosted relay/signal server";
    };

    openFirewall = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Open the required RustDesk ports in the firewall";
    };

    relayHosts = lib.mkOption {
      type        = lib.types.listOf lib.types.str;
      description = "Public IP(s) or hostname(s) clients will use to reach the relay";
      example     = [ "rustdesk.example.com" ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.rustdesk-server = {
      enable      = true;
      openFirewall = cfg.openFirewall;

      relay.enable = true;

      signal = {
        enable     = true;
        relayHosts = cfg.relayHosts;
      };
    };
  };
}