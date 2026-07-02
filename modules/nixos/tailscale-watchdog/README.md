# Tailscale Watchdog

Periodic Tailscale connectivity monitor that sends email alerts and activates ZeroTier as a fallback.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.services.tailscaleWatchdog.enable` | bool | false | Enable watchdog |
| `my.services.tailscaleWatchdog.interval` | string | `"10min"` | Check interval (OnUnitActiveSec) |
| `my.services.tailscaleWatchdog.startDelay` | string | `"5min"` | Delay before first check (OnBootSec) |
| `my.services.tailscaleWatchdog.alertCooldown` | int | `3600` | Min seconds between duplicate alerts |
| `my.services.tailscaleWatchdog.stateDir` | string | `/var/lib/tailscale-watchdog` | State directory |
| `my.services.tailscaleWatchdog.emailTo` | null or string | null | Alert recipient override |

## Usage

```nix
my.services.tailscaleWatchdog = {
  enable = true;
  interval = "5min";
};
```

## Dependencies

- **NixOS modules**: tailscaled, my.services.emailAlerts
- **Flake inputs**: none

## Notes

- When Tailscale goes down, ZeroTier is started as a fallback mesh (if the zerotierone service unit exists).
- When Tailscale recovers, ZeroTier is stopped automatically.
- Cooldown tracking uses epoch timestamps in `stateDir` to prevent alert spam.
- `emailTo` defaults to `my.services.emailAlerts.to` if not set.
