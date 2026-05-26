{ lib, config, pkgs, ... }:

let
  cfg = config.my.services.pxeServer;
in
{
  options.my.services.pxeServer = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable PXE boot server (DHCP + TFTP + HTTP)";
    };

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
        listen = [
          { addr = "0.0.0.0"; port = 8080; }
        ];
        locations."/" = {
          extraConfig = "autoindex on;";
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = [ 8080 ];
      allowedUDPPorts = [ 67 68 69 ];
    };

    systemd.services.pxe-setup = {
      description = "PXE Server — deploy boot files";
      after = [ "network.target" "nginx.service" ];
      wants = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      before = [ "dnsmasq.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        mkdir -p /srv/tftp/ipxe /srv/pxe/windows

        if [ ! -f /srv/tftp/ipxe.efi ]; then
          cp ${pkgs.ipxe}/ipxe.efi /srv/tftp/ipxe.efi
        fi

        if [ ! -f /srv/tftp/undionly.kpxe ]; then
          cp ${pkgs.ipxe}/undionly.kpxe /srv/tftp/undionly.kpxe
        fi

        if [ ! -f /srv/tftp/wimboot ]; then
          cp ${pkgs.wimboot}/wimboot /srv/tftp/wimboot
        fi

        cp ${./pxe-server/boot.ipxe} /srv/tftp/ipxe/boot.ipxe
      '';
    };
  };
}
