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
        (tailscale0 missing/down, MTU drifted from my.services.tailscale.mtu,
        self-path ping fails, or no online peer answers a through-tunnel ping).
        BackendState == "Running" only proves tailscaled's userspace is up — it
        does not prove the tunnel forwards packets.
      '';
    };

    canaryPeers = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "100.121.125.58" "100.70.43.44" ];
      description = ''
        Tailnet IPs probed for remote data-plane health. If empty, the watchdog
        auto-selects the most recently seen Online peer (skipping iOS/Windows,
        which may not answer ICMP). The probe pings each candidate THROUGH
        tailscale0; when at least one candidate answers, the data plane is
        healthy. If every candidate fails on two attempts, the tunnel is not
        forwarding packets and tailscaled is restarted (autoRepair) + alerted.
        Set these explicitly to pin the probe to always-on hosts.
      '';
    };
  };
}
