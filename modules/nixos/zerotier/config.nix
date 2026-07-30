{ config, lib, pkgs, ... }:
let
  inherit (lib) mkIf mkForce;
  cfg = config.my.services.zerotier;
in
{
  config = mkIf cfg.enable {
    services.zerotierone = {
      enable = true;
      joinNetworks = cfg.networks;
      localConf = if cfg.localConf != null then cfg.localConf else { };
      package = if cfg.package != null then cfg.package else pkgs.zerotierone;
    };

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [ 9993 ];

    # Always-on recovery mesh — fully independent of Tailscale.
    # Starts at boot on multi-user.target. UDP 9993 exposed by default (openFirewall).
    systemd.services.zerotierone = {
      wantedBy = [ "multi-user.target" ];
      after = [ "network-pre.target" ];
      wants = [ "network-pre.target" ];
      serviceConfig = {
        Restart = mkForce "on-failure";
        RestartSec = "5";
      };
    };
  };
}
