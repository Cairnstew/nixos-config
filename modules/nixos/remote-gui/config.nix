{ config, lib, ... }:
let
  cfg = config.my.services.remoteGui;
in
{
  config = lib.mkIf cfg.enable {
    # Opening this only matters for non-trusted interfaces (LAN / ZeroTier).
    # tailnet clients bypass the firewall entirely (tailscale0 is trusted).
    networking.firewall.allowedTCPPorts =
      lib.mkIf (cfg.vnc.enable && cfg.vnc.openFirewall) [ cfg.vnc.port ];
  };
}
