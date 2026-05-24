# Battery

Power management for laptops: auto-cpufreq, thermald, lid switch behavior, and suspend control.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.system.battery.enable` | `false` | Enable auto-cpufreq with thermald |
| `my.system.battery.lidSwitch` | `"suspend"` | Lid close action on battery |
| `my.system.battery.lidSwitchExternalPower` | `"ignore"` | Lid close action on AC power |
| `my.system.battery.lidSwitchDocked` | `"ignore"` | Lid close action while docked |
| `my.system.battery.disableSuspend` | `false` | Completely disable suspend/sleep/hibernate |

## Usage

```nix
my.system.battery = {
  enable = true;
  lidSwitch = "hibernate";
};
```

Or via the profile option:

```nix
my.profiles.battery.enable = true;
```

## Notes

- Disables TLP and power-profiles-daemon (conflicting managers).
- Uses `auto-cpufreq` with powersave governor on battery, performance on charger.
- Uses `thermald` for thermal management.
- `disableSuspend` nukes all systemd suspend/sleep/hibernate targets for remote-access machines.
