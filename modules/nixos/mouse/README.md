# Mouse (maccel)

Mouse acceleration via the maccel kernel module with runtime parameter application and diagnostics.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `my.hardware.mouse.enable` | bool | false | Enable mouse acceleration via maccel |
| `my.hardware.mouse.parameters.mode` | null or enum | "linear" | Acceleration curve mode |
| `my.hardware.mouse.parameters.sensMultiplier` | null or float | 2.0 | Sensitivity multiplier |
| `my.hardware.mouse.parameters.yxRatio` | null or float | null | Y/X axis sensitivity ratio |
| `my.hardware.mouse.parameters.inputDpi` | null or positive float | null | Mouse DPI for normalization |
| `my.hardware.mouse.parameters.angleRotation` | null or float | null | Rotation in degrees |
| `my.hardware.mouse.parameters.acceleration` | null or float | 0.3 | Linear acceleration factor |
| `my.hardware.mouse.parameters.offset` | null or non-negative float | 4.0 | Speed threshold for acceleration |
| `my.hardware.mouse.parameters.outputCap` | null or float | 2.0 | Maximum sensitivity cap |
| `my.hardware.mouse.parameters.decayRate` | null or positive float | null | Natural curve decay rate |
| `my.hardware.mouse.parameters.limit` | null or float >= 1.0 | null | Natural curve limit |
| `my.hardware.mouse.parameters.gamma` | null or positive float | null | Natural curve midpoint transition |
| `my.hardware.mouse.parameters.smooth` | null or float [0,1] | null | Sensitivity increase suddenness |
| `my.hardware.mouse.parameters.motivity` | null or float > 1.0 | null | Max sensitivity multiplier range |
| `my.hardware.mouse.parameters.syncSpeed` | null or positive float | null | Middle sensitivity between min and max |
| `my.hardware.mouse.logging.enable` | bool | true | Periodic maccel state logging |
| `my.hardware.mouse.logging.interval` | str | "5min" | Systemd timer interval |
| `my.hardware.mouse.logging.watch` | bool | true | Install maccel-watch CLI helper |
| `my.hardware.mouse.logging.logAll` | bool | false | Log all params on every check |
| `my.hardware.mouse.logging.sysfsWatch` | bool | true | Watch sysfs for unexpected changes |
| `my.hardware.mouse.gnome.accelProfile` | str | "flat" | GNOME mouse acceleration profile |
| `my.hardware.mouse.gnome.speed` | float | 0.0 | GNOME pointer speed |

## Usage

```nix
my.hardware.mouse = {
  enable = true;
  parameters = {
    mode = "linear";
    acceleration = 0.3;
    sensMultiplier = 2.0;
  };
};
```

## Dependencies

- **Flake inputs**: `maccel` (kernel module + CLI + NixOS module)
- **Packages**: maccel-cli (built from flake input)

## Notes

- Runtime param application is handled via systemd (not just module load time).
- GNOME integration sets accel-profile to "flat" to avoid double-acceleration.
- `maccel-watch` CLI provides interactive monitoring (`--diff`, `--watch`, `--json`).
- Logging detects unexpected maccel parameter changes and logs to journald.
