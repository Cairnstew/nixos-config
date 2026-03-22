{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.zerotier;
in
{
  options.my.services.zerotier = {
    enable = lib.mkEnableOption "ZeroTier system service";
    networks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "8056c2e21c000001" ];
      description = ''
        List of ZeroTier network IDs that the system should
        automatically join at boot.
      '';
    };
    mtu = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      example = 1280;
      description = "MTU to set on ZeroTier interfaces. Useful to prevent stalling on large transfers.";
    };

    dnsServer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "ZeroNSD server IP to use for home.arpa resolution";
      example = "192.168.191.168";
    };

    dnsDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "~home.arpa" ];
      example = [ "~home.arpa" "~zt.example.com" ];
      description = "Domains to route to the ZeroNSD server. Prefix with ~ for routing-only (no search).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      joinNetworks = cfg.networks;
    };
    services.resolved = lib.mkIf (cfg.dnsServer != null) {
      enable = true;
      extraConfig = ''
        [Resolve]
        DNS=${cfg.dnsServer}
        Domains=${lib.concatStringsSep " " cfg.dnsDomains}
      '';
    };

    systemd.services.zerotier-mtu = lib.mkIf (cfg.mtu != null) {
      description = "Set MTU on ZeroTier interfaces";
      wantedBy = [ "multi-user.target" ];
      after    = [ "zerotierone.service" "network-online.target" ];
      wants    = [ "network-online.target" ];
      requires = [ "zerotierone.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
        ExecStart = pkgs.writeShellScript "zt-mtu" ''
          for iface in $(${lib.getExe' pkgs.iproute2 "ip"} -o link show | ${pkgs.gnugrep}/bin/grep -oP '^\d+:\s+\Kzt\S+(?=@|:)'); do
            echo "Setting MTU on $iface to ${toString cfg.mtu}"
            ${lib.getExe' pkgs.iproute2 "ip"} link set "$iface" mtu ${toString cfg.mtu}
          done
        '';
      };
    };
  };
}