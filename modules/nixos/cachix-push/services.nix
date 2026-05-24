{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.cachix-push;
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.cachix-push = {
      description = "Push system closure to Cachix";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "cachix-push" ''
          export CACHIX_AUTH_TOKEN=$(cat ${cfg.tokenFile})
          ${if cfg.paths == [ ]
            then "${pkgs.cachix}/bin/cachix push ${cfg.cacheName} /run/current-system"
            else lib.concatMapStringsSep "\n" (p: "${pkgs.cachix}/bin/cachix push ${cfg.cacheName} ${p}") cfg.paths
          }
        '';
      };
    };

    systemd.timers.cachix-push = {
      description = "Timer for Cachix push";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
      };
    };
  };
}
