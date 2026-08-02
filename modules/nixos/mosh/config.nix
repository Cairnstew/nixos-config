{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.mosh;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    programs.mosh = {
      enable = true;
      inherit (cfg) package openFirewall;
      withUtempter = false;
    };

    environment.systemPackages = lib.optionals cfg.installTmux [ pkgs.tmux ];

    # mosh bootstraps over SSH but then uses UDP. When openFirewall is off,
    # the tailnet interface (already trusted) still carries mosh UDP traffic.
    networking.firewall.interfaces.tailscale0.allowedUDPPortRanges = lib.mkIf (!cfg.openFirewall) [
      { from = 60000; to = 61000; }
    ];
  };
}
