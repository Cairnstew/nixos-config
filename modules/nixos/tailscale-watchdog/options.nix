{ lib, flake, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.my.services.tailscaleWatchdog = {
    enable = mkEnableOption "Periodic Tailscale connectivity watchdog with email alerts";

    interval = mkOption {
      type = types.str;
      default = "10min";
      description = "How often to check Tailscale status (OnUnitActiveSec).";
    };

    startDelay = mkOption {
      type = types.str;
      default = "5min";
      description = "Delay after boot before first check (OnBootSec).";
    };

    alertCooldown = mkOption {
      type = types.int;
      default = 3600;
      description = "Minimum seconds between duplicate email alerts (cooldown).";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/tailscale-watchdog";
      description = "State directory path for alert cooldown tracking.";
    };

    emailTo = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Override recipient for watchdog alerts. If null, uses the default
        from my.services.emailAlerts.to.
      '';
    };

    autoRepair = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Restart tailscaled automatically when the kernel data plane is unhealthy
        (tailscale0 missing/down, MTU drifted from my.services.tailscale.mtu, or
        self-path ping fails). BackendState == "Running" only proves tailscaled's
        userspace is up — it does not prove the tunnel forwards packets.
      '';
    };
  };
}
