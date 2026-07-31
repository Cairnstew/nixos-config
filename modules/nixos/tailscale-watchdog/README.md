# Tailscale Watchdog

Periodic Tailscale connectivity monitor that probes the kernel data plane, sends email alerts, and auto-repairs a wedged tunnel.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.tailscaleWatchdog.enable` | bool | false | Enable watchdog |
| `my.services.tailscaleWatchdog.interval` | string | `"10min"` | Check interval (OnUnitActiveSec) |
| `my.services.tailscaleWatchdog.startDelay` | string | `"5min"` | Delay before first check (OnBootSec) |
| `my.services.tailscaleWatchdog.alertCooldown` | int | `3600` | Min seconds between duplicate alerts |
| `my.services.tailscaleWatchdog.stateDir` | string | `/var/lib/tailscale-watchdog` | State directory |
| `my.services.tailscaleWatchdog.emailTo` | null or string | null | Alert recipient override |
| `my.services.tailscaleWatchdog.autoRepair` | bool | `true` | Restart tailscaled on data-plane failure |

## Usage

```nix
my.services.tailscaleWatchdog = {
  enable = true;
  interval = "5min";
};
```

## Dependencies

- **NixOS modules**: tailscaled, my.services.emailAlerts, my.services.tailscale
- **Flake inputs**: none

## Notes

- `BackendState == "Running"` only proves tailscaled's userspace is up. The
  watchdog additionally probes the **kernel data plane**: tailscale0 exists and
  is UP, its MTU matches `my.services.tailscale.mtu` (if set), and a self-path
  ping to the tailnet IP succeeds.
- A wedge looks like: all TCP/ICMP to the host times out, yet `tailscale ping`
  still pongs — the tunnel is "up" but no packets reach the kernel.
- When the data plane is unhealthy and `autoRepair` is true, the watchdog
  restarts `tailscaled` (the documented recovery) and emails an alert.
- Cooldown tracking uses epoch timestamps in `stateDir` to prevent alert spam.
- `emailTo` defaults to `my.services.emailAlerts.to` if not set.
