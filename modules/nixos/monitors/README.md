# Monitors

Declarative monitor layout configuration consumed by desktop environment modules.

## Options (`my.monitors` — list of monitors)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | str | — | Connector name (e.g. DP-1, eDP-1, HDMI-A-1) |
| `width` | int | — | Horizontal resolution in pixels |
| `height` | int | — | Vertical resolution in pixels |
| `refreshRate` | number | 60 | Refresh rate in Hz |
| `scale` | number | 1 | Scale factor (1 = 100%, 1.5 = 150%) |
| `x` | int | 0 | X position in the layout |
| `y` | int | 0 | Y position in the layout |
| `primary` | bool | false | Whether this is the primary monitor |
| `workspace` | str | "1" | Workspace assigned to this monitor |
| `enabled` | bool | true | Whether this monitor is enabled |
| `transform` | int | 0 | Display transform (0=normal, 1=90°, 2=180°, 3=270°) |

## Usage

```nix
my.monitors = [
  {
    name = "DP-1";
    width = 2560;
    height = 1440;
    refreshRate = 144;
    primary = true;
  }
  {
    name = "HDMI-A-1";
    width = 1920;
    height = 1080;
    x = 2560;
  }
];
```

## Dependencies

- **NixOS modules**: Desktop environment modules (e.g. Hyprland) consume this option

## Notes

- This is an options-only module with no config.nix — it defines the data model for desktop environments.
- Transform values: 0=normal, 1=90° CW, 2=180°, 3=270° CW, 4-7=flipped variants.
