{ lib, ... }:
{
  options.my.services.pxeServer = {
    enable = lib.mkEnableOption "PXE boot server (DHCP + TFTP + HTTP)";

    interface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "Network interface to listen on for DHCP and TFTP";
    };

    dhcpRange = lib.mkOption {
      type = lib.types.str;
      default = "192.168.100.100,192.168.100.200";
      description = "DHCP lease range (start,end)";
    };

    serverIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.100.1";
      description = "Server IP for DHCP next-server, TFTP, and HTTP base URL";
    };
  };
}
