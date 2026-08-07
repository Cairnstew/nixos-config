{ lib, ... }:
{
  # Options moved from config.nix for AGENT.md §2 file-responsibility compliance (T8).
  options.my.services.natShare = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Share internet connection via ethernet using NAT";
    };

    wanInterface = lib.mkOption {
      type = lib.types.str;
      default = "wlan0";
      description = "The interface with internet access (your WiFi)";
      example = "wlan0";
    };

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "The interface to share internet over (your ethernet port)";
      example = "eth0";
    };

    lanAddress = lib.mkOption {
      type = lib.types.str;
      default = "192.168.99.1";
      description = "Static IP to assign to the LAN interface on this machine";
    };

    dhcpRangeStart = lib.mkOption {
      type = lib.types.str;
      default = "192.168.99.10";
      description = "Start of DHCP range handed out to connected devices";
    };

    dhcpRangeEnd = lib.mkOption {
      type = lib.types.str;
      default = "192.168.99.254";
      description = "End of DHCP range handed out to connected devices";
    };

    extraDnsmasqSettings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Extra dnsmasq settings merged into the main settings attrset.
        Used by the netboot module to inject PXE boot options
        (enable-tftp, dhcp-boot, dhcp-match) when co-located.
      '';
    };
  };
}
