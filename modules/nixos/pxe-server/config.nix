{ lib, config, ... }:
let
  cfg = config.my.services.pxeServer;
in
{
  config = lib.mkIf cfg.enable {
    services.dnsmasq = {
      enable = true;
      settings = {
        interface = cfg.interface;
        bind-interfaces = true;
        dhcp-range = cfg.dhcpRange;
        dhcp-option = [
          "option:ntp-server,${cfg.serverIp}"
          "option:dns-server,${cfg.serverIp}"
          "66,${cfg.serverIp}"
        ];
        enable-tftp = true;
        tftp-root = "/srv/tftp";
        dhcp-match = [
          "set:efi-x86_64,option:client-arch,7"
          "set:bios,option:client-arch,0"
        ];
        dhcp-boot = [
          "tag:efi-x86_64,ipxe.efi"
          "tag:bios,undionly.kpxe"
        ];
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."pxe" = {
        root = "/srv/pxe";
        listen = [{ addr = "0.0.0.0"; port = 8080; }];
        locations."/" = {
          extraConfig = "autoindex on;";
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 8080 ];
      allowedUDPPorts = [ 67 68 69 ];
    };
  };
}
