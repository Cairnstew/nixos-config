# modules/nixos/cachix-push.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.my.services.cachix-push;
in {
  options.my.services.cachix-push = {
    enable = lib.mkEnableOption "Cachix push service";

    cacheName = lib.mkOption {
      type = lib.types.str;
      description = "Name of the Cachix cache to push to";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing the Cachix auth token (e.g. from agenix)";
    };

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Store paths to push. If empty, pushes the current system toplevel.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "Systemd calendar expression for how often to push. See systemd.time(7).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.cachix-push = {
      description = "Push system closure to Cachix";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "cachix-push" ''
          export CACHIX_AUTH_TOKEN=$(cat ${cfg.tokenFile})
          ${if cfg.paths == []
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