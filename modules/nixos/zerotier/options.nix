{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.zerotier = {
    enable = mkEnableOption "ZeroTier One mesh VPN";

    networks = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "8056c2e21c000001" ];
      description = "ZeroTier network IDs to join on startup.";
    };

    localConf = mkOption {
      type = types.nullOr types.attrs;
      default = null;
      description = "Optional ZeroTier local.conf attrs (e.g. { settings.allowTcpFallbackRelay = false; }).";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open the ZeroTier port in the firewall.";
    };

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      description = "ZeroTierOne package to use. Defaults to pkgs.zerotierone.";
    };

    mtu = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 1300;
      description = ''
        MTU to force on every ZeroTier `zt*` interface once it appears.

        ZeroTier advertises 2800 bytes regardless of what the underlying path
        actually carries. When traffic is relayed (or crosses a WAN link with a
        smaller MTU) the real limit can be ~1300, so any datagram larger than
        that is fragmented past the path and silently dropped, while tiny
        control packets still get through. A protocol that opens with one large
        "here is everything" packet then hangs on a connection that looks
        perfectly healthy in both logs and in `ping`.

        `null` leaves ZeroTier's default. Set it to the measured path MTU
        (`ping -M do -s <payload>` against a peer) minus the headers, e.g. 1300
        when payloads of 1272 pass but 1300 do not.
      '';
    };
  };
}
