{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.mssClamp = {
    enable = mkEnableOption "TCP MSS clamping on mesh tunnel interfaces (fixes MTU blackholes)";

    mss = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        Maximum Segment Size to set on SYN packets exiting/entering the tunnel
        interfaces. If null, derived from `my.services.tailscale.mtu` as
        `mtu - 60` (tunnel MTU minus worst-case IPv6(40)+TCP(20) headers),
        falling back to 1140 when the tailscale MTU is unset (assumes a 1280
        wire path: 1280 - 140).
      '';
      example = 1140;
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = [ "tailscale0" ];
      description = ''
        Tunnel interfaces to clamp MSS on. tailscaled recreates tailscale0 at
        MTU 1280 on every restart/re-auth, blackholing large TCP packets while
        small probes (tailscale ping) still pass — these rules make the tunnel
        survive that by clamping MSS to fit the real wire path. Rules are
        applied on OUTPUT and INPUT so locally-terminated traffic (SSH to the
        box) is covered, not just forwarded traffic.
      '';
    };

    reassertInterval = mkOption {
      type = types.str;
      default = "10min";
      description = "How often to re-assert the clamp rules via a timer (insurance against mangle flush).";
    };
  };
}
