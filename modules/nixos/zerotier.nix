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
      description = "ZeroNSD server IP to use for DNS resolution.";
      example = "192.168.191.168";
    };

    dnsDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "~zt" ];
      example = [ "~zt" "~home.arpa" ];
      description = ''
        Domains to route to the ZeroNSD server.
        Prefix with ~ for routing-only (no search domain).
      '';
    };

    allowDNS = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to run `zerotier-cli set <network> allowDNS=1` at boot.
        Enable on clients so ZeroTier Central pushes DNS config to them.
        Typically disabled on the server running zeronsd itself.
      '';
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
        FallbackDNS=1.1.1.1
      '';
    };

    # Prevent conflict with nixos-wsl's generateResolvConf management.
    # mkDefault allows WSL (or any host) to override this without a collision.
    networking.resolvconf.enable = lib.mkDefault false;

    # Tell ZeroTier to accept DNS config pushed from ZeroTier Central.
    systemd.services.zerotier-dns = lib.mkIf (cfg.allowDNS && cfg.dnsServer != null) {
      description = "Enable ZeroTier DNS for networks";
      wantedBy = [ "multi-user.target" ];
      after    = [ "zerotierone.service" ];
      requires = [ "zerotierone.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "zt-dns" ''
          for network in ${lib.concatStringsSep " " cfg.networks}; do
            ${pkgs.zerotierone}/bin/zerotier-cli \
              -D/var/lib/zerotier-one \
              set "$network" allowDNS=1
          done
        '';
      };
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
