# Hyprland

Hyprland Wayland compositor desktop environment. Organized as a modular set of submodules under `my.desktop.hyprland.*`.

## Quick Start

```nix
my.desktop.hyprland = {
  enable = true;
  user = "seanc";
};

my.monitors = [
  { name = "DP-1"; width = 2560; height = 1440; refreshRate = 144; x = 0; y = 0; primary = true; workspace = "1"; }
];
```

## Options

### Master Options (`my.desktop.hyprland.*`)

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable Hyprland and all default submodules |
| `user` | str | `me.username` | Primary user for the Hyprland session |
| — | — | — | `nvidia.enable` is set via submodule (see below) |
| `extraPackages` | list | `[]` | Additional system packages |
| `terminal` | pkg | `pkgs.ghostty` | Default terminal (SUPER+Return) |
| `useMonitors` | bool | `true` | Use `my.monitors` for display config |

### Submodule Options (`my.desktop.hyprland.<module>.*`)

Set `parent.enable = true` to enable all default submodules. Each can be overridden:

| Submodule | Option | Type | Default | Description |
|-----------|--------|------|---------|-------------|
| `core` | `enable` | bool | `true` | Compositor core: programs.hyprland, env vars, appearance, keybinds |
| `bar` | `enable` | bool | `true` | Waybar status bar |
| | `style` | lines | `""` | Extra CSS for waybar |
| | `position` | enum | `"top"` | Waybar position (`top`/`bottom`) |
| | `height` | int | `30` | Waybar height in pixels |
| `launcher` | `enable` | bool | `true` | Wofi app launcher (SUPER+D) |
| | `package` | pkg | `pkgs.wofi` | Launcher package |
| | `args` | str | `"--show drun"` | Extra launcher args |
| `notifications` | `enable` | bool | `true` | Mako notification daemon |
| | `position` | enum | `"top-right"` | Popup position |
| | `defaultTimeout` | int | `5000` | Timeout in ms |
| | `width` | int | `380` | Popup width |
| `wallpapers` | `enable` | bool | `true` | Unified wallpaper management (hyprpaper/awww/mpvpaper/waypaper) |
| | `backend` | enum | `"hyprpaper"` | Wallpaper daemon: `hyprpaper`, `awww`, `mpvpaper`, or `waypaper` |
| | `images` | list | `[]` | Wallpaper paths `[{path, output?}]` |
| | `settings.awww.transitionType` | enum | `null` | awww transition effect |
| | `settings.awww.transitionStep` | int | `null` | awww transition smoothness |
| | `settings.awww.transitionFps` | int | `null` | awww transition frame rate |
| | `settings.awww.transitionAngle` | int | `null` | awww wipe angle |
| | `settings.awww.daemonArgs` | list | `[]` | Extra awww-daemon args |
| | `settings.mpvpaper.mpvOptions` | str | `"no-audio --loop-file=inf …"` | mpv options for mpvpaper |
| | `settings.mpvpaper.ipcSocket` | str | `null` | mpvpaper IPC socket path |
| | `settings.waypaper.backend` | enum | `"swaybg"` | Internal backend for Waypaper GUI |
| | `settings.waypaper.folder` | path | `null` | Wallpaper folder for Waypaper GUI |
| | `settings.waypaper.fillOption` | enum | `"cover"` | Fill mode (`cover`/`fill`/`fit`/`center`/`stretch`/`tile`) |
| `lockscreen` | `enable` | bool | `true` | Screen locker (SUPER+L) |
| | `package` | pkg | `pkgs.swaylock` | Lock screen package |
| | `useHyprlock` | bool | `false` | Use hyprlock instead of swaylock |
| `screenshot` | `enable` | bool | `true` | Grim+slurp (SUPER+SHIFT+S, Print) |
| | `directory` | str | `"~/Pictures"` | Screenshot directory |
| `clipboard` | `enable` | bool | `true` | wl-clipboard + cliphist |
| | `history` | bool | `true` | Enable cliphist |
| `portal` | `enable` | bool | `true` | xdg-desktop-portal-hyprland |
| `displayManager` | `enable` | bool | `true` | Greetd + tuigreet TTY greeter |
| | `greeter` | pkg | `pkgs.tuigreet` | Greeter package |
| | `sessionCommand` | str | `"Hyprland"` | Session command |
| `audio` | `enable` | bool | `true` | PipeWire + WirePlumber |
| `utilities` | `enable` | bool | `true` | polkit, thunar, gvfs, tumbler, nm-applet, fonts, brightnessctl, playerctl, imv, mpv, GTK theme |
| `nvidia` | `enable` | bool | `false` | Nvidia modesetting + kernel params + env vars (LIBVA_DRIVER_NAME, etc.) |

### Opt-in Submodules (disabled by default)

| Submodule | Option | Type | Default | Description |
|-----------|--------|------|---------|-------------|
| `idle` | `enable` | bool | `false` | Hypridle: auto-lock and suspend on inactivity |
| | `lockTimeout` | int | `300` | Seconds before lock (0=disable) |
| | `dpmsTimeout` | int | `600` | Seconds before DPMS off (0=disable) |
| | `suspendTimeout` | int | `900` | Seconds before suspend (0=disable) |
| `colorpicker` | `enable` | bool | `false` | Hyprpicker color picker (SUPER+SHIFT+P) |
| `nightLight` | `enable` | bool | `false` | Hyprsunset blue-light filter (SUPER+SHIFT+N) |
| | `temperature` | int | `3500` | Color temperature in Kelvin |
| `pyprland` | `enable` | bool | `false` | Pyprland IPC plugins (scratchpads, expose, etc.) |
| | `plugins` | list | `[]` | Plugin names to enable |
| `awww` | `enable` | bool | `false` | Standalone awww (use `wallpapers.backend = "awww"` instead) |

## Per-Monitor Configuration

Use the `my.monitors` option (defined in `modules/nixos/monitors/`) for display layout:

```nix
my.monitors = [
  { name = "DP-1"; width = 2560; height = 1440; refreshRate = 144;
    x = 0; y = 0; primary = true; workspace = "1"; }
  { name = "DP-2"; width = 1920; height = 1200; refreshRate = 60;
    x = 2560; y = 0; workspace = "2"; transform = 1; }
];
```

The `transform` field supports rotation: 0=normal, 1=90° (portrait), 2=180°, 3=270°.

## Enabling New Tools

All new tools are opt-in. Add to your host config:

```nix
my.desktop.hyprland = {
  idle.enable = true;
  colorpicker.enable = true;
  nightLight.enable = true;
  pyprland.enable = true;
  pyprland.plugins = [ "scratchpads" "expose" "monitors" ];
  wallpapers.backend = "awww";
  wallpapers.images = [
    { path = "/path/to/wallpaper.png"; }
    { path = "/path/to/other.png"; output = "DP-1"; }
  ];
  wallpapers.settings.awww.transitionType = "center";
};
```
