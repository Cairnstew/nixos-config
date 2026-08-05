# Mouse acceleration via maccel — option-gated orchestration.
#
# F9d split: the maccel CLI package expression moved to packages.nix, and the
# maccel-watch / maccel-logger scripts moved to services.nix (imported below as
# a plain function).  The maccel NixOS module import moved to default.nix so
# this file contains no `imports`.  Only the mkIf-gated wiring + HM dconf stay
# here.
{ config, lib, pkgs, flake, ... }:
let
  cfg = config.my.hardware.mouse;

  # maccelBin / maccelWatch / maccelLogger / applyParamsCmds, computed in
  # services.nix from the shared maccel CLI package (packages.nix).
  maccel = import ./services.nix { inherit config lib pkgs flake; };
in
{
  config = lib.mkIf cfg.enable {
    hardware.maccel = {
      enable = true;
      enableCli = true;

      parameters = {
        mode = cfg.parameters.mode;
        sensMultiplier = cfg.parameters.sensMultiplier;
        yxRatio = cfg.parameters.yxRatio;
        inputDpi = cfg.parameters.inputDpi;
        angleRotation = cfg.parameters.angleRotation;
        acceleration = cfg.parameters.acceleration;
        offset = cfg.parameters.offset;
        outputCap = cfg.parameters.outputCap;
        decayRate = cfg.parameters.decayRate;
        limit = cfg.parameters.limit;
        gamma = cfg.parameters.gamma;
        smooth = cfg.parameters.smooth;
        motivity = cfg.parameters.motivity;
        syncSpeed = cfg.parameters.syncSpeed;
      };
    };

    # Install maccel-watch CLI for interactive diagnostics
    environment.systemPackages = lib.mkIf cfg.logging.watch [ maccel.maccelWatch ];

    systemd = {
      services = {
        # Runtime param application — applies the Nix-configured params to the
        # already-loaded kernel module. This is necessary because modprobe
        # options only take effect at module load time (reboot).
        maccel-apply-params = {
          description = "Apply maccel kernel module parameters at runtime";
          after = [ "systemd-modules-load.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = lib.concatStringsSep "\n" maccel.applyParamsCmds;
        };

        # Periodic health check logger
        maccel-logger = lib.mkIf cfg.logging.enable {
          description = "maccel periodic health check — logs state and detects unexpected changes";
          after = [ "maccel-apply-params.service" ];
          wants = [ "maccel-apply-params.service" ];
          serviceConfig.Type = "oneshot";
          script = "${maccel.maccelLogger}";
        };

        # Boot audit: log initial state immediately after params are applied.
        # Logger may return non-zero if module isn't ready (e.g. during switch);
        # that's diagnostic noise, not a service failure.
        maccel-audit = lib.mkIf cfg.logging.enable {
          description = "maccel boot-time state audit";
          after = [ "maccel-apply-params.service" ];
          requires = [ "maccel-apply-params.service" ];
          before = [ "multi-user.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = ''
            echo "=== maccel boot audit ==="
            ${maccel.maccelLogger} || echo "MACVEL audit: logger exited $?, continuing"
            echo "=== end maccel boot audit ==="
          '';
        };
      };

      timers.maccel-logger = lib.mkIf cfg.logging.enable {
        description = "Periodic maccel state check timer";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "hourly";
          OnBootSec = "1min";
          OnUnitActiveSec = cfg.logging.interval;
          RandomizedDelaySec = "30s";
          Persistent = true;
        };
      };
    };

    # GNOME integration: ensure GNOME's own acceleration is flat so the
    # kernel-level maccel curve is the only active acceleration.
    home-manager.users.${flake.config.me.username}.dconf.settings."org/gnome/desktop/peripherals/mouse" =
      lib.mkIf config.my.desktop.gnome.enable {
        accel-profile = cfg.gnome.accelProfile;
        speed = cfg.gnome.speed;
      };
  };
}
