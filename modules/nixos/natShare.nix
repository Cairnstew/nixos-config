{ lib, config, ... }:
let
  cfg = config.my.services.natShare;
in
{
  options.my.services.natShare = {
    enable = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Share internet connection via ethernet using NAT";
    };

    wanInterface = lib.mkOption {
      type    = lib.types.str;
      default = "wlan0";
      description = "The interface with internet access (your WiFi)";
      example  = "wlan0";
    };

    lanInterface = lib.mkOption {
      type    = lib.types.str;
      default = "eth0";
      description = "The interface to share internet over (your ethernet port)";
      example  = "eth0";
    };

    lanAddress = lib.mkOption {
      type    = lib.types.str;
      default = "192.168.99.1";
      description = "Static IP to assign to the LAN interface on this machine";
    };

    dhcpRangeStart = lib.mkOption {
      type    = lib.types.str;
      default = "192.168.99.10";
      description = "Start of DHCP range handed out to connected devices";
    };

    dhcpRangeEnd = lib.mkOption {
      type    = lib.types.str;
      default = "192.168.99.254";
      description = "End of DHCP range handed out to connected devices";
    };
  };

  config = lib.mkIf cfg.enable {
    # Assign static IP to the ethernet port
    networking.interfaces.${cfg.lanInterface} = {
      ipv4.addresses = [{
        address      = cfg.lanAddress;
        prefixLength = 24;
      }];
    };

    # Enable NAT from LAN → WAN
    networking.nat = {
      enable            = true;
      internalInterfaces    = [ cfg.lanInterface ];
      externalInterface = cfg.wanInterface;
    };

    # DHCP server so the connected device gets an IP automatically
    services.dnsmasq = {
      enable = true;
      settings = {
        interface       = cfg.lanInterface;
        bind-interfaces = true;
        dhcp-range      = "${cfg.dhcpRangeStart},${cfg.dhcpRangeEnd},24h";
      };
    };

    # Allow traffic forwarding and DNS/DHCP through the firewall
    networking.firewall = {
      allowedUDPPorts = [ 53 67 ];   # DNS + DHCP
      allowedTCPPorts = [ 53 ];      # DNS
      trustedInterfaces = [ cfg.lanInterface ];
    };
  };
}