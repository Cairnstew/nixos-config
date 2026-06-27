{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.ssh = {
    enable = mkEnableOption "SSH daemon with auto-generated root key";

    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "SSH public keys authorized for root login.";
    };

    lanSubnets = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "192.168.1.0/24" "10.0.0.0/8" ];
      description = ''
        Subnets from which password + keyboard-interactive authentication is
        always allowed as a last-resort fallback. This ensures you can always
        SSH into a headless machine via the physical LAN even if all mesh VPNs
        (Tailscale, ZeroTier) are down.

        Tailscale uses 100.64.0.0/10 which is NOT a private subnet, so it will
        never match this. ZeroTier typically uses 10.0.0.0/8 — if that overlaps
        with your LAN, be specific about your LAN's actual subnet.

        Set to [ ] (default) to disable the LAN fallback entirely.
      '';
    };
  };
}
