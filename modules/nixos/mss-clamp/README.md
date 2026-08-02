# MSS Clamp

TCP MSS clamping on mesh tunnel interfaces. Fixes the "large TCP packets
blackholed while `tailscale ping` works" failure mode caused by tailscaled
resetting `tailscale0` to MTU 1280 on restart/re-auth. Tailscale only installs
MSS-clamp rules for *forwarded* traffic, never OUTPUT/INPUT (i.e. SSH to the
box), so this module clamps both.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.services.mssClamp.enable` | `false` | Enable MSS clamping |
| `my.services.mssClamp.mss` | `null` | MSS value (auto-derived from tailscale MTU − 60, fallback 1140) |
| `my.services.mssClamp.interfaces` | `["tailscale0"]` | Tunnel interfaces to clamp |
| `my.services.mssClamp.reassertInterval` | `"10min"` | Timer re-assert interval |

## Usage Example

```nix
my.services.mssClamp.enable = true;
```

## Notes

- Uses the iptables `mangle` table (OUTPUT + INPUT chains), which survives
  TUN recreation — interface matches are resolved at packet time.
- Auto-derives MSS: `tailscale mtu 1200 → 1140` (1200 − 60), else 1140
  (1280 wire path − 140).
- iptables rules persist across tailscaled restarts; the timer is insurance
  against mangle being flushed.
