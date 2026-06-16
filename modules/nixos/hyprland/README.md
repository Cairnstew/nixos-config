# Hyprland

Hyprland Wayland compositor desktop environment with waybar, mako, wofi, and greetd display manager.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `my.desktop.hyprland.enable` | `false` | Enable Hyprland desktop |
| `my.desktop.hyprland.user` | `me.username` | Primary user for the Hyprland session |
| `my.desktop.hyprland.nvidia` | `false` | Apply Nvidia-specific env vars |
| `my.desktop.hyprland.extraPackages` | `[]` | Extra system packages |
| `my.desktop.hyprland.useMonitors` | `true` | Use `my.monitors` for display config |

## Usage

```nix
my.desktop.hyprland = {
  enable = true;
  user = "seanc";
};

my.monitors = [
  {
    name = "DP-1";
    width = 2560;
    height = 1440;
    refreshRate = 144;
    x = 0;
    y = 0;
    primary = true;
    workspace = "1";
  }
];
```

## Screen Orientation

Use the `transform` field in `my.monitors` to rotate displays:

| Value | Orientation |
|-------|-------------|
| `0` | Normal |
| `1` | 90° clockwise (portrait) |
| `2` | 180° (upside down) |
| `3` | 270° clockwise |
