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
      localConf = if cfg.localConf != null then builtins.toJSON cfg.localConf else null;
      package = if cfg.package != null then cfg.package else pkgs.zerotierone;
    };

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [ 9993 ];

    # Ensure zerotier starts reliably (parallel mesh with tailscale)
    systemd.services.zerotierone = {
      after = [ "network-pre.target" ];
      wants = [ "network-pre.target" ];
      serviceConfig = {
        Restart = mkForce "on-failure";
        RestartSec = "5";
      };
    };
  };
}
