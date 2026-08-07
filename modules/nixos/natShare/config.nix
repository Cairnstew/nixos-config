{ lib, config, ... }:
let
  cfg = config.my.services.natShare;
in
{
  config = lib.mkIf cfg.enable {
    # Assign static IP to the ethernet port
    networking.interfaces.${cfg.lanInterface} = {
      ipv4.addresses = [{
        address = cfg.lanAddress;
        prefixLength = 24;
      }];
    };

    # Enable NAT from LAN → WAN
    networking.nat = {
      enable = true;
      internalInterfaces = [ cfg.lanInterface ];
      externalInterface = cfg.wanInterface;
    };

    # DHCP server so the connected device gets an IP automatically
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = cfg.lanInterface;
        bind-interfaces = true;
        dhcp-range = "${cfg.dhcpRangeStart},${cfg.dhcpRangeEnd},24h";
      } // cfg.extraDnsmasqSettings;
    };

    # Allow traffic forwarding and DNS/DHCP through the firewall
    networking.firewall = {
      allowedUDPPorts = [ 53 67 ]; # DNS + DHCP
      allowedTCPPorts = [ 53 ]; # DNS
      trustedInterfaces = [ cfg.lanInterface ];
    };
  };
}
